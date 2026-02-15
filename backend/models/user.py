"""
User modeli - Kullanici veritabani modeli
"""

import enum
from sqlalchemy import (
    Column, String, Boolean, DateTime, Enum as SAEnum, func
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid

from core.database import Base


class UserRole(str, enum.Enum):
    """Kullanici rolleri"""
    ADMIN = "admin"
    YONETICI = "yonetici"
    CALISAN = "calisan"
    TARIMCI = "tarimci"
    IZLEYICI = "izleyici"


class User(Base):
    """Kullanici modeli"""
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    firebase_uid = Column(String(128), unique=True, nullable=True, index=True)
    username = Column(String(50), unique=True, nullable=False)
    email = Column(String(100), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=True)
    full_name = Column(String(100), nullable=True)
    phone = Column(String(20), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    role = Column(
        SAEnum(UserRole, name="user_role", create_type=False),
        nullable=False,
        default=UserRole.IZLEYICI,
    )
    is_active = Column(Boolean, default=True)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Iliskiler
    owned_farms = relationship("Farm", back_populates="owner", cascade="all, delete-orphan")
    farm_memberships = relationship("FarmMember", back_populates="user", cascade="all, delete-orphan")
    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="user")

    def __repr__(self) -> str:
        return f"<User(id={self.id}, username={self.username}, role={self.role})>"
