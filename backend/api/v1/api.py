from fastapi import APIRouter
from api.v1.endpoints import gis, auth, users, farms

api_router = APIRouter()
api_router.include_router(gis.router, prefix="/gis", tags=["gis"])
api_router.include_router(auth.router, tags=["auth"])
api_router.include_router(users.router, tags=["users"])
api_router.include_router(farms.router, tags=["farms"])
