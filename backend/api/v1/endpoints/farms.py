"""
Farms endpointleri - Ciftlik yonetimi islemleri
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from uuid import UUID

from core.database import get_db
from core.dependencies import get_current_user, require_admin_or_manager
from models.user import User, UserRole
from models.farm import Farm, FarmMember
from models.audit_log import AuditLog
from schemas.farm import (
    FarmCreate, FarmUpdate, FarmResponse, FarmListResponse,
    FarmMemberAdd, FarmMemberResponse, FarmMemberListResponse,
)

router = APIRouter(prefix="/farms", tags=["farms"])


def _log_action(db: Session, user_id, action: str, request: Request, entity_type: str = "farm", entity_id=None, details: dict = None):
    """Islem gecmisine kayit ekler"""
    ip = request.client.host if request.client else None
    log = AuditLog(
        user_id=user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        details=details,
        ip_address=ip,
    )
    db.add(log)


def _check_farm_access(db: Session, farm_id: UUID, user: User) -> Farm:
    """Kullanicinin ciftlige erisim hakki var mi kontrol eder"""
    farm = db.query(Farm).filter(Farm.id == farm_id).first()
    if farm is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ciftlik bulunamadi")
    if user.role == UserRole.ADMIN:
        return farm
    if farm.owner_id == user.id:
        return farm
    membership = db.query(FarmMember).filter(
        FarmMember.farm_id == farm_id,
        FarmMember.user_id == user.id,
    ).first()
    if membership is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Bu ciftlige erisim yetkiniz yok")
    return farm


@router.post("", response_model=FarmResponse, status_code=status.HTTP_201_CREATED)
def create_farm(
    body: FarmCreate,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Yeni ciftlik olustur"""
    farm = Farm(
        name=body.name,
        description=body.description,
        owner_id=current_user.id,
        address=body.address,
        latitude=body.latitude,
        longitude=body.longitude,
        area_hectares=body.area_hectares,
    )
    db.add(farm)
    db.flush()
    # Sahibi otomatik olarak yonetici uye olarak ekle
    membership = FarmMember(
        farm_id=farm.id,
        user_id=current_user.id,
        role=UserRole.YONETICI,
    )
    db.add(membership)
    _log_action(db, current_user.id, "farm_create", request, entity_id=farm.id, details={"name": body.name})
    db.commit()
    db.refresh(farm)
    return FarmResponse.model_validate(farm)


@router.get("", response_model=FarmListResponse)
def list_farms(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Kullanicinin erisimi olan ciftlikleri listele"""
    if current_user.role == UserRole.ADMIN:
        farms = db.query(Farm).filter(Farm.is_active == True).all()
    else:
        # Sahip oldugu + uye oldugu ciftlikler
        owned = db.query(Farm).filter(Farm.owner_id == current_user.id, Farm.is_active == True).all()
        member_farm_ids = db.query(FarmMember.farm_id).filter(FarmMember.user_id == current_user.id).all()
        member_ids = [fid[0] for fid in member_farm_ids]
        member_farms = db.query(Farm).filter(Farm.id.in_(member_ids), Farm.is_active == True).all() if member_ids else []
        seen_ids = set()
        farms = []
        for f in owned + member_farms:
            if f.id not in seen_ids:
                farms.append(f)
                seen_ids.add(f.id)
    return FarmListResponse(
        farms=[FarmResponse.model_validate(f) for f in farms],
        total=len(farms),
    )


@router.put("/{farm_id}", response_model=FarmResponse)
def update_farm(
    farm_id: UUID,
    body: FarmUpdate,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Ciftlik bilgilerini guncelle"""
    farm = _check_farm_access(db, farm_id, current_user)
    # Sadece sahip veya admin guncelleyebilir
    if farm.owner_id != current_user.id and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Sadece ciftlik sahibi veya admin guncelleyebilir")
    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(farm, key, value)
    _log_action(db, current_user.id, "farm_update", request, entity_id=farm_id, details=update_data)
    db.commit()
    db.refresh(farm)
    return FarmResponse.model_validate(farm)


@router.post("/{farm_id}/members", response_model=FarmMemberResponse, status_code=status.HTTP_201_CREATED)
def add_farm_member(
    farm_id: UUID,
    body: FarmMemberAdd,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Ciftlige uye ekle"""
    farm = _check_farm_access(db, farm_id, current_user)
    if farm.owner_id != current_user.id and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Sadece ciftlik sahibi veya admin uye ekleyebilir")
    # Kullanicinin var olup olmadigini kontrol et
    target_user = db.query(User).filter(User.id == body.user_id, User.is_active == True).first()
    if target_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Eklenecek kullanici bulunamadi")
    # Zaten uye mi kontrol et
    existing = db.query(FarmMember).filter(
        FarmMember.farm_id == farm_id,
        FarmMember.user_id == body.user_id,
    ).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu kullanici zaten ciftlik uyesi")
    try:
        member_role = UserRole(body.role)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Gecersiz rol: {body.role}")
    member = FarmMember(
        farm_id=farm_id,
        user_id=body.user_id,
        role=member_role,
    )
    db.add(member)
    _log_action(
        db, current_user.id, "farm_member_add", request,
        entity_type="farm_member", entity_id=farm_id,
        details={"user_id": str(body.user_id), "role": body.role},
    )
    db.commit()
    db.refresh(member)
    return FarmMemberResponse(
        id=member.id,
        farm_id=member.farm_id,
        user_id=member.user_id,
        username=target_user.username,
        full_name=target_user.full_name,
        email=target_user.email,
        role=member.role.value,
        joined_at=member.joined_at,
    )


@router.delete("/{farm_id}/members/{user_id}")
def remove_farm_member(
    farm_id: UUID,
    user_id: UUID,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Ciftlikten uye cikar"""
    farm = _check_farm_access(db, farm_id, current_user)
    if farm.owner_id != current_user.id and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Sadece ciftlik sahibi veya admin uye cikarabilir")
    if farm.owner_id == user_id:
        raise HTTPException(status_code=400, detail="Ciftlik sahibi cikarilamaz")
    member = db.query(FarmMember).filter(
        FarmMember.farm_id == farm_id,
        FarmMember.user_id == user_id,
    ).first()
    if member is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Uyelik bulunamadi")
    db.delete(member)
    _log_action(
        db, current_user.id, "farm_member_remove", request,
        entity_type="farm_member", entity_id=farm_id,
        details={"removed_user_id": str(user_id)},
    )
    db.commit()
    return {"message": "Uye basariyla cikarildi"}


@router.get("/{farm_id}/members", response_model=FarmMemberListResponse)
def list_farm_members(
    farm_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Ciftlik uyelerini listele"""
    _check_farm_access(db, farm_id, current_user)
    members = db.query(FarmMember).filter(FarmMember.farm_id == farm_id).all()
    result = []
    for m in members:
        user = db.query(User).filter(User.id == m.user_id).first()
        result.append(FarmMemberResponse(
            id=m.id,
            farm_id=m.farm_id,
            user_id=m.user_id,
            username=user.username if user else None,
            full_name=user.full_name if user else None,
            email=user.email if user else None,
            role=m.role.value,
            joined_at=m.joined_at,
        ))
    return FarmMemberListResponse(members=result, total=len(result))
