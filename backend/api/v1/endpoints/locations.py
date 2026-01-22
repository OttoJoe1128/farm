"""
Locations API endpoints
Lokasyon API uç noktaları
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from uuid import UUID

from core.database import get_db
from schemas.location import LocationCreate, LocationUpdate, LocationResponse
from services.location_service import LocationService

router = APIRouter()

@router.get("/", response_model=List[LocationResponse])
async def get_locations(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Get all saved locations"""
    service = LocationService(db)
    return await service.get_locations(skip=skip, limit=limit)

@router.post("/", response_model=LocationResponse, status_code=status.HTTP_201_CREATED)
async def create_location(
    location: LocationCreate,
    db: Session = Depends(get_db)
):
    """Create a new saved location"""
    service = LocationService(db)
    return await service.create_location(location)

@router.get("/{location_id}", response_model=LocationResponse)
async def get_location(
    location_id: UUID,
    db: Session = Depends(get_db)
):
    """Get a specific location by ID"""
    service = LocationService(db)
    location = await service.get_location(location_id)
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Location not found"
        )
    return location

@router.put("/{location_id}", response_model=LocationResponse)
async def update_location(
    location_id: UUID,
    location_update: LocationUpdate,
    db: Session = Depends(get_db)
):
    """Update a location"""
    service = LocationService(db)
    location = await service.update_location(location_id, location_update)
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Location not found"
        )
    return location

@router.delete("/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_location(
    location_id: UUID,
    db: Session = Depends(get_db)
):
    """Delete a location"""
    service = LocationService(db)
    success = await service.delete_location(location_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Location not found"
        )
