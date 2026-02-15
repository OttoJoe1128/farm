"""
Auth endpointleri - Kimlik dogrulama ve kayit islemleri
"""

from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from core.database import get_db
from core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token,
    hash_refresh_token,
)
from core.firebase import verify_firebase_token
from core.dependencies import get_current_user
from models.user import User, UserRole
from models.refresh_token import RefreshToken
from models.audit_log import AuditLog
from schemas.auth import (
    FirebaseVerifyRequest, RegisterRequest, LoginRequest,
    RefreshTokenRequest, TokenResponse, UserBrief,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _build_token_response(user: User, db: Session) -> TokenResponse:
    """Kullanici icin token yaniti olusturur"""
    access_token = create_access_token(str(user.id), user.role.value)
    raw_refresh, token_hash, expires_at = create_refresh_token(str(user.id))
    refresh_record = RefreshToken(
        user_id=user.id,
        token_hash=token_hash,
        expires_at=expires_at,
    )
    db.add(refresh_record)
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()
    return TokenResponse(
        access_token=access_token,
        refresh_token=raw_refresh,
        token_type="bearer",
        expires_in=30 * 60,
        user=UserBrief(
            id=user.id,
            username=user.username,
            email=user.email,
            full_name=user.full_name,
            role=user.role.value,
            avatar_url=user.avatar_url,
        ),
    )


def _log_action(db: Session, user_id, action: str, request: Request, details: dict = None):
    """Islem gecmisine kayit ekler"""
    ip = request.client.host if request.client else None
    log = AuditLog(
        user_id=user_id,
        action=action,
        entity_type="user",
        entity_id=user_id,
        details=details,
        ip_address=ip,
    )
    db.add(log)


@router.post("/verify-firebase", response_model=TokenResponse)
def verify_firebase(
    body: FirebaseVerifyRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Firebase ID token dogrula ve JWT uret"""
    firebase_data = verify_firebase_token(body.id_token)
    if firebase_data is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Gecersiz Firebase token",
        )
    firebase_uid = firebase_data["uid"]
    email = firebase_data.get("email")
    name = firebase_data.get("name")
    picture = firebase_data.get("picture")
    # Mevcut kullaniciyi bul veya olustur
    user = db.query(User).filter(User.firebase_uid == firebase_uid).first()
    if user is None and email:
        user = db.query(User).filter(User.email == email).first()
        if user:
            user.firebase_uid = firebase_uid
    if user is None:
        username = email.split("@")[0] if email else f"user_{firebase_uid[:8]}"
        # Benzersiz username kontrolu
        existing = db.query(User).filter(User.username == username).first()
        counter = 1
        base_username = username
        while existing:
            username = f"{base_username}{counter}"
            existing = db.query(User).filter(User.username == username).first()
            counter += 1
        user = User(
            firebase_uid=firebase_uid,
            username=username,
            email=email or f"{firebase_uid}@firebase.local",
            full_name=name,
            avatar_url=picture,
            role=UserRole.IZLEYICI,
            is_active=True,
        )
        db.add(user)
        db.flush()
        _log_action(db, user.id, "register_firebase", request, {"firebase_uid": firebase_uid})
    else:
        if name and not user.full_name:
            user.full_name = name
        if picture and not user.avatar_url:
            user.avatar_url = picture
        _log_action(db, user.id, "login_firebase", request)
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hesabiniz deaktif edilmis",
        )
    return _build_token_response(user, db)


@router.post("/register", response_model=TokenResponse)
def register(
    body: RegisterRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Email/sifre ile yeni kullanici kaydi"""
    # Benzersizlik kontrolu
    existing_email = db.query(User).filter(User.email == body.email).first()
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu e-posta adresi zaten kayitli",
        )
    existing_username = db.query(User).filter(User.username == body.username).first()
    if existing_username:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Bu kullanici adi zaten alinmis",
        )
    user = User(
        username=body.username,
        email=body.email,
        password_hash=hash_password(body.password),
        full_name=body.full_name,
        phone=body.phone,
        role=UserRole.IZLEYICI,
        is_active=True,
    )
    db.add(user)
    db.flush()
    _log_action(db, user.id, "register", request)
    return _build_token_response(user, db)


@router.post("/login", response_model=TokenResponse)
def login(
    body: LoginRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Email/sifre ile giris"""
    user = db.query(User).filter(User.email == body.email).first()
    if user is None or user.password_hash is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Gecersiz e-posta veya sifre",
        )
    if not verify_password(body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Gecersiz e-posta veya sifre",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Hesabiniz deaktif edilmis",
        )
    _log_action(db, user.id, "login", request)
    return _build_token_response(user, db)


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(
    body: RefreshTokenRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Refresh token ile yeni access token al"""
    token_hash = hash_refresh_token(body.refresh_token)
    record = db.query(RefreshToken).filter(
        RefreshToken.token_hash == token_hash,
        RefreshToken.is_revoked == False,
    ).first()
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Gecersiz refresh token",
        )
    if record.expires_at < datetime.now(timezone.utc):
        record.is_revoked = True
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token suresi dolmus",
        )
    # Eski token'i iptal et
    record.is_revoked = True
    user = db.query(User).filter(User.id == record.user_id, User.is_active == True).first()
    if user is None:
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Kullanici bulunamadi",
        )
    _log_action(db, user.id, "token_refresh", request)
    return _build_token_response(user, db)


@router.post("/logout")
def logout(
    body: RefreshTokenRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Cikis yap - Refresh token'i iptal et"""
    token_hash = hash_refresh_token(body.refresh_token)
    record = db.query(RefreshToken).filter(
        RefreshToken.token_hash == token_hash,
        RefreshToken.user_id == current_user.id,
    ).first()
    if record:
        record.is_revoked = True
    _log_action(db, current_user.id, "logout", request)
    db.commit()
    return {"message": "Basariyla cikis yapildi"}


@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    """Mevcut kullanici bilgilerini getir"""
    return UserBrief(
        id=current_user.id,
        username=current_user.username,
        email=current_user.email,
        full_name=current_user.full_name,
        role=current_user.role.value,
        avatar_url=current_user.avatar_url,
    )
