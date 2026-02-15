"""
Farm semalari - Ciftlik yonetimi icin Pydantic semalari
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from decimal import Decimal


class FarmCreate(BaseModel):
    """Yeni ciftlik olusturma"""
    name: str = Field(..., min_length=1, max_length=150)
    description: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[Decimal] = Field(None, ge=-90, le=90)
    longitude: Optional[Decimal] = Field(None, ge=-180, le=180)
    area_hectares: Optional[Decimal] = Field(None, ge=0)


class FarmUpdate(BaseModel):
    """Ciftlik guncelleme"""
    name: Optional[str] = Field(None, min_length=1, max_length=150)
    description: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[Decimal] = Field(None, ge=-90, le=90)
    longitude: Optional[Decimal] = Field(None, ge=-180, le=180)
    area_hectares: Optional[Decimal] = Field(None, ge=0)


class FarmResponse(BaseModel):
    """Ciftlik yaniti"""
    id: UUID
    name: str
    description: Optional[str] = None
    owner_id: UUID
    address: Optional[str] = None
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None
    area_hectares: Optional[Decimal] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class FarmListResponse(BaseModel):
    """Ciftlik listesi yaniti"""
    farms: List[FarmResponse]
    total: int


class FarmMemberAdd(BaseModel):
    """Ciftlige uye ekleme"""
    user_id: UUID = Field(..., description="Eklenecek kullanici ID")
    role: str = Field(default="calisan", description="Ciftlik icerisindeki rol")


class FarmMemberResponse(BaseModel):
    """Ciftlik uyesi yaniti"""
    id: UUID
    farm_id: UUID
    user_id: UUID
    username: Optional[str] = None
    full_name: Optional[str] = None
    email: Optional[str] = None
    role: str
    joined_at: datetime

    class Config:
        from_attributes = True


class FarmMemberListResponse(BaseModel):
    """Ciftlik uyeleri listesi yaniti"""
    members: List[FarmMemberResponse]
    total: int
