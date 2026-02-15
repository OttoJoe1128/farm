"""
Auth semalari - Kimlik dogrulama icin Pydantic semalari
"""

from pydantic import BaseModel, Field, EmailStr
from typing import Optional
from uuid import UUID


class FirebaseVerifyRequest(BaseModel):
    """Firebase token dogrulama istegi"""
    id_token: str = Field(..., description="Firebase ID token")


class RegisterRequest(BaseModel):
    """Dogrudan kayit istegi (Firebase kullanmadan)"""
    username: str = Field(..., min_length=3, max_length=50, description="Kullanici adi")
    email: str = Field(..., description="E-posta adresi")
    password: str = Field(..., min_length=8, max_length=128, description="Sifre")
    full_name: Optional[str] = Field(None, max_length=100, description="Tam ad")
    phone: Optional[str] = Field(None, max_length=20, description="Telefon numarasi")


class LoginRequest(BaseModel):
    """Giris istegi"""
    email: str = Field(..., description="E-posta adresi")
    password: str = Field(..., description="Sifre")


class RefreshTokenRequest(BaseModel):
    """Token yenileme istegi"""
    refresh_token: str = Field(..., description="Refresh token")


class TokenResponse(BaseModel):
    """Token yaniti"""
    access_token: str = Field(..., description="JWT access token")
    refresh_token: str = Field(..., description="JWT refresh token")
    token_type: str = Field(default="bearer", description="Token tipi")
    expires_in: int = Field(..., description="Token gecerlilik suresi (saniye)")
    user: "UserBrief"


class UserBrief(BaseModel):
    """Kisa kullanici bilgisi (token yaniti icinde)"""
    id: UUID
    username: str
    email: str
    full_name: Optional[str] = None
    role: str
    avatar_url: Optional[str] = None

    class Config:
        from_attributes = True


# Forward reference guncelleme
TokenResponse.model_rebuild()
