"""
User semalari - Kullanici yonetimi icin Pydantic semalari
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime


class UserCreate(BaseModel):
    """Yeni kullanici olusturma"""
    username: str = Field(..., min_length=3, max_length=50)
    email: str = Field(...)
    password: Optional[str] = Field(None, min_length=8, max_length=128)
    full_name: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    role: str = Field(default="izleyici")
    firebase_uid: Optional[str] = Field(None, max_length=128)


class UserUpdate(BaseModel):
    """Kullanici guncelleme"""
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    email: Optional[str] = None
    full_name: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    avatar_url: Optional[str] = Field(None, max_length=500)


class UserRoleUpdate(BaseModel):
    """Kullanici rol degistirme (sadece admin)"""
    role: str = Field(..., description="Yeni rol: admin, yonetici, calisan, tarimci, izleyici")


class UserResponse(BaseModel):
    """Kullanici yaniti"""
    id: UUID
    username: str
    email: str
    full_name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None
    role: str
    is_active: bool
    last_login_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserListResponse(BaseModel):
    """Kullanici listesi yaniti"""
    users: List[UserResponse]
    total: int
    page: int
    page_size: int


class AuditLogResponse(BaseModel):
    """Islem gecmisi yaniti"""
    id: UUID
    user_id: Optional[UUID] = None
    action: str
    entity_type: Optional[str] = None
    entity_id: Optional[UUID] = None
    details: Optional[dict] = None
    ip_address: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class AuditLogListResponse(BaseModel):
    """Islem gecmisi listesi yaniti"""
    logs: List[AuditLogResponse]
    total: int
    page: int
    page_size: int
