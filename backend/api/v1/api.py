"""
API v1 router
"""

from fastapi import APIRouter
from api.v1.endpoints import locations, designs, objects

api_router = APIRouter()

# Include endpoint routers
api_router.include_router(
    locations.router,
    prefix="/locations",
    tags=["locations"]
)

api_router.include_router(
    designs.router,
    prefix="/designs", 
    tags=["designs"]
)

api_router.include_router(
    objects.router,
    prefix="/objects",
    tags=["objects"]
)
