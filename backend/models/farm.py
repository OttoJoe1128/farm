"""
Farm ve FarmMember modelleri - Ciftlik veritabani modelleri
"""

from sqlalchemy import (
    Column, String, Boolean, DateTime, Numeric, Text, ForeignKey,
    Enum as SAEnum, UniqueConstraint, func
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
import uuid

from core.database import Base
from models.user import UserRole


class Farm(Base):
    """Ciftlik modeli"""
    __tablename__ = "farms"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(150), nullable=False)
    description = Column(Text, nullable=True)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    address = Column(Text, nullable=True)
    latitude = Column(Numeric(10, 8), nullable=True)
    longitude = Column(Numeric(11, 8), nullable=True)
    area_hectares = Column(Numeric(10, 2), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Iliskiler
    owner = relationship("User", back_populates="owned_farms")
    members = relationship("FarmMember", back_populates="farm", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Farm(id={self.id}, name={self.name})>"


class FarmMember(Base):
    """Ciftlik uyesi modeli"""
    __tablename__ = "farm_members"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    farm_id = Column(UUID(as_uuid=True), ForeignKey("farms.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(
        SAEnum(UserRole, name="user_role", create_type=False),
        nullable=False,
        default=UserRole.CALISAN,
    )
    joined_at = Column(DateTime(timezone=True), server_default=func.now())

    # Iliskiler
    farm = relationship("Farm", back_populates="members")
    user = relationship("User", back_populates="farm_memberships")

    __table_args__ = (
        UniqueConstraint("farm_id", "user_id", name="uq_farm_member"),
    )

    def __repr__(self) -> str:
        return f"<FarmMember(farm_id={self.farm_id}, user_id={self.user_id}, role={self.role})>"
