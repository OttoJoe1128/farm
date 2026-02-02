from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.v1.api import api_router

app = FastAPI(title="SmartFarm XR API")

# CORS AYARLARI (Flutter'ın erişebilmesi için kapıları açıyoruz)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Güvenlik için ileride kısıtlanabilir
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rotaları Tanımla
app.include_router(api_router, prefix="/api/v1")

@app.get("/")
async def root():
    return {"message": "SmartFarm XR Backend Çalışıyor! (GIS Modülü Aktif)"}
