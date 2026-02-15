"""
Users endpointleri - Kullanici yonetimi islemleri
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlalchemy.orm import Session
from uuid import UUID

from core.database import get_db
from core.dependencies import get_current_user, require_admin, require_admin_or_manager
from models.user import User, UserRole
from models.audit_log import AuditLog
from schemas.user import (
    UserResponse, UserListResponse, UserUpdate, UserRoleUpdate,
    AuditLogResponse, AuditLogListResponse,
)

router = APIRouter(prefix="/users", tags=["users"])


def _log_action(db: Session, user_id, action: str, request: Request, entity_type: str = "user", entity_id=None, details: dict = None):
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


@router.get("", response_model=UserListResponse)
def list_users(
    request: Request,
    page: int = Query(1, ge=1, description="Sayfa numarasi"),
    page_size: int = Query(20, ge=1, le=100, description="Sayfa basi kayit"),
    search: str = Query(None, description="Arama (isim, email, kullanici adi)"),
    role: str = Query(None, description="Role gore filtre"),
    is_active: bool = Query(None, description="Aktiflik durumu"),
    current_user: User = Depends(require_admin_or_manager),
    db: Session = Depends(get_db),
):
    """Kullanicilari listele (admin/yonetici)"""
    query = db.query(User)
    if search:
        search_pattern = f"%{search}%"
        query = query.filter(
            (User.username.ilike(search_pattern)) |
            (User.email.ilike(search_pattern)) |
            (User.full_name.ilike(search_pattern))
        )
    if role:
        try:
            query = query.filter(User.role == UserRole(role))
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Gecersiz rol: {role}")
    if is_active is not None:
        query = query.filter(User.is_active == is_active)
    total = query.count()
    offset = (page - 1) * page_size
    users = query.order_by(User.created_at.desc()).offset(offset).limit(page_size).all()
    return UserListResponse(
        users=[UserResponse.model_validate(u) for u in users],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{user_id}", response_model=UserResponse)
def get_user(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Kullanici detay bilgisi getir"""
    # Kendi profilini veya admin/yonetici ise baskasinin profilini gorebilir
    if str(current_user.id) != str(user_id) and current_user.role not in (UserRole.ADMIN, UserRole.YONETICI):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Yetkiniz yok")
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kullanici bulunamadi")
    return UserResponse.model_validate(user)


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: UUID,
    body: UserUpdate,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Kullanici bilgilerini guncelle"""
    # Kendi profilini veya admin ise baskasinin profilini guncelleyebilir
    if str(current_user.id) != str(user_id) and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Yetkiniz yok")
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kullanici bulunamadi")
    update_data = body.model_dump(exclude_unset=True)
    # Benzersizlik kontrolu
    if "username" in update_data and update_data["username"] != user.username:
        existing = db.query(User).filter(User.username == update_data["username"]).first()
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu kullanici adi zaten alinmis")
    if "email" in update_data and update_data["email"] != user.email:
        existing = db.query(User).filter(User.email == update_data["email"]).first()
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Bu e-posta zaten kayitli")
    for key, value in update_data.items():
        setattr(user, key, value)
    _log_action(db, current_user.id, "user_update", request, entity_id=user_id, details=update_data)
    db.commit()
    db.refresh(user)
    return UserResponse.model_validate(user)


@router.put("/{user_id}/role", response_model=UserResponse)
def update_user_role(
    user_id: UUID,
    body: UserRoleUpdate,
    request: Request,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Kullanici rolunu degistir (sadece admin)"""
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kullanici bulunamadi")
    try:
        new_role = UserRole(body.role)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Gecersiz rol: {body.role}")
    old_role = user.role.value
    user.role = new_role
    _log_action(
        db, current_user.id, "role_change", request,
        entity_id=user_id,
        details={"old_role": old_role, "new_role": body.role},
    )
    db.commit()
    db.refresh(user)
    return UserResponse.model_validate(user)


@router.delete("/{user_id}")
def deactivate_user(
    user_id: UUID,
    request: Request,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Kullanici hesabini deaktive et (sadece admin)"""
    if str(current_user.id) == str(user_id):
        raise HTTPException(status_code=400, detail="Kendi hesabinizi deaktive edemezsiniz")
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Kullanici bulunamadi")
    user.is_active = False
    _log_action(db, current_user.id, "user_deactivate", request, entity_id=user_id)
    db.commit()
    return {"message": f"Kullanici '{user.username}' deaktive edildi"}


@router.get("/{user_id}/audit-log", response_model=AuditLogListResponse)
def get_user_audit_log(
    user_id: UUID,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(require_admin_or_manager),
    db: Session = Depends(get_db),
):
    """Kullanici islem gecmisi"""
    query = db.query(AuditLog).filter(AuditLog.user_id == user_id)
    total = query.count()
    offset = (page - 1) * page_size
    logs = query.order_by(AuditLog.created_at.desc()).offset(offset).limit(page_size).all()
    return AuditLogListResponse(
        logs=[AuditLogResponse.model_validate(log) for log in logs],
        total=total,
        page=page,
        page_size=page_size,
    )
