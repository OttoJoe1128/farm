"""
Admin panel router - Web tabanli yonetim paneli endpointleri
"""

from fastapi import APIRouter, Depends, Request, HTTPException, Form, Query
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional
import os

from core.database import get_db
from core.security import verify_password, hash_password, create_access_token
from core.config import settings
from models.user import User, UserRole
from models.farm import Farm, FarmMember
from models.audit_log import AuditLog

router = APIRouter(prefix="/admin", tags=["admin"])

templates_dir = os.path.join(os.path.dirname(__file__), "templates")
templates = Jinja2Templates(directory=templates_dir)

# Basit session yonetimi (uretim ortaminda Redis kullanilmali)
admin_sessions: dict = {}


def _get_admin_user(request: Request, db: Session) -> Optional[User]:
    """Cookie'den admin kullanicisini dogrular"""
    session_id = request.cookies.get("admin_session")
    if not session_id or session_id not in admin_sessions:
        return None
    user_id = admin_sessions[session_id]
    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if user is None or user.role != UserRole.ADMIN:
        return None
    return user


@router.get("/login", response_class=HTMLResponse)
def admin_login_page(request: Request, error: str = None):
    """Admin giris sayfasi"""
    return templates.TemplateResponse("login.html", {"request": request, "error": error})


@router.post("/login")
def admin_login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db),
):
    """Admin giris islemi"""
    user = db.query(User).filter(User.email == email).first()
    if user is None or user.password_hash is None:
        return RedirectResponse(url="/admin/login?error=Gecersiz+giris+bilgileri", status_code=303)
    if not verify_password(password, user.password_hash):
        return RedirectResponse(url="/admin/login?error=Gecersiz+giris+bilgileri", status_code=303)
    if user.role != UserRole.ADMIN:
        return RedirectResponse(url="/admin/login?error=Admin+yetkisi+gerekli", status_code=303)
    import secrets
    session_id = secrets.token_urlsafe(32)
    admin_sessions[session_id] = user.id
    response = RedirectResponse(url="/admin/dashboard", status_code=303)
    response.set_cookie("admin_session", session_id, httponly=True, max_age=3600)
    return response


@router.get("/logout")
def admin_logout(request: Request):
    """Admin cikis"""
    session_id = request.cookies.get("admin_session")
    if session_id and session_id in admin_sessions:
        del admin_sessions[session_id]
    response = RedirectResponse(url="/admin/login", status_code=303)
    response.delete_cookie("admin_session")
    return response


@router.get("/dashboard", response_class=HTMLResponse)
def admin_dashboard(request: Request, db: Session = Depends(get_db)):
    """Admin ana panel"""
    admin_user = _get_admin_user(request, db)
    if admin_user is None:
        return RedirectResponse(url="/admin/login", status_code=303)
    total_users = db.query(func.count(User.id)).scalar()
    active_users = db.query(func.count(User.id)).filter(User.is_active == True).scalar()
    total_farms = db.query(func.count(Farm.id)).scalar()
    recent_logs = db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(10).all()
    # Rol dagilimi
    role_counts = {}
    for role in UserRole:
        count = db.query(func.count(User.id)).filter(User.role == role).scalar()
        role_counts[role.value] = count
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "admin_user": admin_user,
        "total_users": total_users,
        "active_users": active_users,
        "total_farms": total_farms,
        "recent_logs": recent_logs,
        "role_counts": role_counts,
    })


@router.get("/users", response_class=HTMLResponse)
def admin_users(
    request: Request,
    page: int = Query(1, ge=1),
    search: str = Query(None),
    role: str = Query(None),
    db: Session = Depends(get_db),
):
    """Kullanici yonetimi sayfasi"""
    admin_user = _get_admin_user(request, db)
    if admin_user is None:
        return RedirectResponse(url="/admin/login", status_code=303)
    page_size = 20
    query = db.query(User)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (User.username.ilike(pattern)) |
            (User.email.ilike(pattern)) |
            (User.full_name.ilike(pattern))
        )
    if role:
        try:
            query = query.filter(User.role == UserRole(role))
        except ValueError:
            pass
    total = query.count()
    users = query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    total_pages = (total + page_size - 1) // page_size
    return templates.TemplateResponse("users.html", {
        "request": request,
        "admin_user": admin_user,
        "users": users,
        "total": total,
        "page": page,
        "total_pages": total_pages,
        "search": search or "",
        "role_filter": role or "",
        "roles": [r.value for r in UserRole],
    })


@router.post("/users/{user_id}/role")
def admin_update_role(
    user_id: str,
    request: Request,
    new_role: str = Form(...),
    db: Session = Depends(get_db),
):
    """Kullanici rolunu degistir"""
    admin_user = _get_admin_user(request, db)
    if admin_user is None:
        return RedirectResponse(url="/admin/login", status_code=303)
    user = db.query(User).filter(User.id == user_id).first()
    if user:
        try:
            user.role = UserRole(new_role)
            log = AuditLog(
                user_id=admin_user.id,
                action="admin_role_change",
                entity_type="user",
                entity_id=user.id,
                details={"new_role": new_role},
                ip_address=request.client.host if request.client else None,
            )
            db.add(log)
            db.commit()
        except ValueError:
            pass
    return RedirectResponse(url="/admin/users", status_code=303)


@router.post("/users/{user_id}/toggle-active")
def admin_toggle_active(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """Kullanici aktiflik durumunu degistir"""
    admin_user = _get_admin_user(request, db)
    if admin_user is None:
        return RedirectResponse(url="/admin/login", status_code=303)
    user = db.query(User).filter(User.id == user_id).first()
    if user and str(user.id) != str(admin_user.id):
        user.is_active = not user.is_active
        log = AuditLog(
            user_id=admin_user.id,
            action="admin_toggle_active",
            entity_type="user",
            entity_id=user.id,
            details={"is_active": user.is_active},
            ip_address=request.client.host if request.client else None,
        )
        db.add(log)
        db.commit()
    return RedirectResponse(url="/admin/users", status_code=303)


@router.get("/farms", response_class=HTMLResponse)
def admin_farms(request: Request, db: Session = Depends(get_db)):
    """Ciftlik yonetimi sayfasi"""
    admin_user = _get_admin_user(request, db)
    if admin_user is None:
        return RedirectResponse(url="/admin/login", status_code=303)
    farms = db.query(Farm).order_by(Farm.created_at.desc()).all()
    farm_data = []
    for farm in farms:
        owner = db.query(User).filter(User.id == farm.owner_id).first()
        member_count = db.query(func.count(FarmMember.id)).filter(FarmMember.farm_id == farm.id).scalar()
        farm_data.append({
            "farm": farm,
            "owner": owner,
            "member_count": member_count,
        })
    return templates.TemplateResponse("farms.html", {
        "request": request,
        "admin_user": admin_user,
        "farm_data": farm_data,
    })


@router.get("/audit-log", response_class=HTMLResponse)
def admin_audit_log(
    request: Request,
    page: int = Query(1, ge=1),
    action: str = Query(None),
    db: Session = Depends(get_db),
):
    """Islem gecmisi sayfasi"""
    admin_user = _get_admin_user(request, db)
    if admin_user is None:
        return RedirectResponse(url="/admin/login", status_code=303)
    page_size = 30
    query = db.query(AuditLog)
    if action:
        query = query.filter(AuditLog.action == action)
    total = query.count()
    logs = query.order_by(AuditLog.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    total_pages = (total + page_size - 1) // page_size
    # Her log icin kullanici adini getir
    log_data = []
    for log in logs:
        user = db.query(User).filter(User.id == log.user_id).first() if log.user_id else None
        log_data.append({"log": log, "username": user.username if user else "Bilinmiyor"})
    return templates.TemplateResponse("audit_log.html", {
        "request": request,
        "admin_user": admin_user,
        "log_data": log_data,
        "total": total,
        "page": page,
        "total_pages": total_pages,
        "action_filter": action or "",
    })
