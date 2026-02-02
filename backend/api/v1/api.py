from fastapi import APIRouter
from api.v1.endpoints import gis

api_router = APIRouter()
api_router.include_router(gis.router, prefix="/gis", tags=["gis"])
