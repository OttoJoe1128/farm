"""
Permission modeli - Izin veritabani modeli
"""

from sqlalchemy import (
    Column, String, Boolean, Enum as SAEnum, UniqueConstraint
)
from sqlalchemy.dialects.postgresql import UUID
import uuid

from core.database import Base
from models.user import UserRole


class Permission(Base):
    """Izin modeli - Rol bazli izin tanimlari"""
    __tablename__ = "permissions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    role = Column(
        SAEnum(UserRole, name="user_role", create_type=False),
        nullable=False,
    )
    permission_key = Column(String(50), nullable=False)
    is_allowed = Column(Boolean, default=True)

    __table_args__ = (
        UniqueConstraint("role", "permission_key", name="uq_role_permission"),
    )

    def __repr__(self) -> str:
        return f"<Permission(role={self.role}, key={self.permission_key}, allowed={self.is_allowed})>"
