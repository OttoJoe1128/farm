"""
Location schemas for API serialization
"""

from pydantic import BaseModel, Field
from typing import Optional
from uuid import UUID
from datetime import datetime
from decimal import Decimal

class LocationBase(BaseModel):
    """Base location schema"""
    name: str = Field(..., min_length=1, max_length=100, description="Location name")
    description: Optional[str] = Field(None, max_length=500, description="Location description")
    latitude: Decimal = Field(..., ge=-90, le=90, description="Latitude coordinate")
    longitude: Decimal = Field(..., ge=-180, le=180, description="Longitude coordinate")
    zoom_level: Optional[int] = Field(15, ge=1, le=20, description="Map zoom level")
    area_size_m2: Optional[Decimal] = Field(None, ge=0, description="Area size in square meters")

class LocationCreate(LocationBase):
    """Schema for creating a new location"""
    user_id: UUID = Field(..., description="User ID who owns this location")

class LocationUpdate(BaseModel):
    """Schema for updating a location"""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    latitude: Optional[Decimal] = Field(None, ge=-90, le=90)
    longitude: Optional[Decimal] = Field(None, ge=-180, le=180)
    zoom_level: Optional[int] = Field(None, ge=1, le=20)
    area_size_m2: Optional[Decimal] = Field(None, ge=0)

class LocationResponse(LocationBase):
    """Schema for location response"""
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
