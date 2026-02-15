"""
Firebase Admin SDK entegrasyonu - Token dogrulama
"""

import firebase_admin
from firebase_admin import credentials, auth as firebase_auth
from typing import Optional, Dict, Any
import os

from core.config import settings

# Firebase Admin SDK baslatma
_firebase_app: Optional[firebase_admin.App] = None


def initialize_firebase() -> None:
    """Firebase Admin SDK'yi baslatir"""
    global _firebase_app
    if _firebase_app is not None:
        return
    cred_path = settings.FIREBASE_CREDENTIALS_PATH
    if not os.path.exists(cred_path):
        print(f"[UYARI] Firebase credentials dosyasi bulunamadi: {cred_path}")
        print("[UYARI] Firebase token dogrulama devre disi kalacak.")
        return
    try:
        cred = credentials.Certificate(cred_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        print("[BILGI] Firebase Admin SDK basariyla baslatildi.")
    except Exception as err:
        print(f"[HATA] Firebase baslatma hatasi: {err}")


def verify_firebase_token(id_token: str) -> Optional[Dict[str, Any]]:
    """
    Firebase ID token dogrular.
    Basarili olursa kullanici bilgilerini dondurur.
    """
    if _firebase_app is None:
        return None
    try:
        decoded_token = firebase_auth.verify_id_token(id_token)
        return {
            "uid": decoded_token.get("uid"),
            "email": decoded_token.get("email"),
            "name": decoded_token.get("name"),
            "picture": decoded_token.get("picture"),
            "email_verified": decoded_token.get("email_verified", False),
        }
    except firebase_auth.InvalidIdTokenError:
        return None
    except firebase_auth.ExpiredIdTokenError:
        return None
    except Exception:
        return None


def is_firebase_initialized() -> bool:
    """Firebase baslatilmis mi kontrol eder"""
    return _firebase_app is not None
