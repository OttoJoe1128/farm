"""
FastAPI dependency'leri - Kimlik dogrulama ve yetkilendirme
"""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import List, Optional

from core.database import get_db
from core.security import verify_access_token
from models.user import User, UserRole
from models.permission import Permission

# Bearer token sema
security_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Mevcut kullaniciyi JWT token'dan cozumler"""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Kimlik dogrulama gerekli",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = verify_access_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Gecersiz veya suresi dolmus token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token icinde kullanici bilgisi bulunamadi",
        )
    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Kullanici bulunamadi veya hesap deaktif",
        )
    return user


def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    db: Session = Depends(get_db),
) -> Optional[User]:
    """Opsiyonel kullanici - token yoksa None dondurur"""
    if credentials is None:
        return None
    payload = verify_access_token(credentials.credentials)
    if payload is None:
        return None
    user_id = payload.get("sub")
    if user_id is None:
        return None
    return db.query(User).filter(User.id == user_id, User.is_active == True).first()


class RequireRole:
    """Rol bazli erisim kontrolu dependency"""
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = [UserRole(r) for r in allowed_roles]

    def __call__(self, current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in self.allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Bu islem icin yetkiniz yok. Gerekli roller: {[r.value for r in self.allowed_roles]}",
            )
        return current_user


class RequirePermission:
    """Izin bazli erisim kontrolu dependency"""
    def __init__(self, permission_key: str):
        self.permission_key = permission_key

    def __call__(
        self,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> User:
        permission = db.query(Permission).filter(
            Permission.role == current_user.role,
            Permission.permission_key == self.permission_key,
            Permission.is_allowed == True,
        ).first()
        if permission is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Bu islem icin '{self.permission_key}' izniniz yok.",
            )
        return current_user


# Sik kullanilan rol dependency'leri
require_admin = RequireRole(["admin"])
require_admin_or_manager = RequireRole(["admin", "yonetici"])
require_any_authenticated = RequireRole(["admin", "yonetici", "calisan", "tarimci", "izleyici"])
