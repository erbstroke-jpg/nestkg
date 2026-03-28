from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.user import User, UserRole, UserStatus
from app.models.listing import Listing, ListingStatus
from app.models.category import Category
from app.models.report import Report, ReportStatus
from app.models.payment import Payment, PaymentStatus
from app.models.audit_log import AuditLog
from app.models.conversation import Conversation
from app.models.message import Message
from app.models.promotion import Promotion, PromotionStatus
from app.models.promotion_package import PromotionPackage
from app.utils.security import verify_password

router = APIRouter(prefix="/admin", tags=["Admin Panel"])
templates = Jinja2Templates(directory="/app/templates")


# ─────────────────────────────────────────────
# DB dependency
# ─────────────────────────────────────────────

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def get_admin_user(request: Request, db: Session) -> Optional[User]:
    user_id = request.session.get("admin_user_id")
    if not user_id:
        return None
    return db.query(User).filter(User.id == user_id, User.role == UserRole.admin).first()


def flash(request: Request, message: str, category: str = "success"):
    request.session["_flash"] = {"message": message, "category": category}


def get_flash(request: Request):
    return request.session.pop("_flash", None)


def log_action(db: Session, admin_id: int, action: str,
               target_type: str = "system", target_id: int = 0, note: str = None):
    entry = AuditLog(
        admin_id=admin_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        details_json={"note": note} if note else None,
    )
    db.add(entry)
    db.commit()


# ─────────────────────────────────────────────
# Auth
# ─────────────────────────────────────────────

@router.get("/login", response_class=HTMLResponse)
def admin_login_page(request: Request):
    if request.session.get("admin_user_id"):
        return RedirectResponse("/admin/dashboard", status_code=302)
    return templates.TemplateResponse(request, "admin/login.html", {})


@router.post("/login", response_class=HTMLResponse)
def admin_login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.password_hash):
        return templates.TemplateResponse(
            request, "admin/login.html",
            {"error": "Неверный email или пароль"},
            status_code=401,
        )
    if user.role != UserRole.admin:
        return templates.TemplateResponse(
            request, "admin/login.html",
            {"error": "Нет прав администратора"},
            status_code=403,
        )
    request.session["admin_user_id"] = user.id
    return RedirectResponse("/admin/dashboard", status_code=302)


@router.get("/logout")
def admin_logout(request: Request):
    request.session.clear()
    return RedirectResponse("/admin/login", status_code=302)


# ─────────────────────────────────────────────
# Dashboard
# ─────────────────────────────────────────────

@router.get("/dashboard", response_class=HTMLResponse)
def dashboard(request: Request, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    stats = {
        "total_users": db.query(func.count(User.id)).scalar(),
        "active_users": db.query(func.count(User.id)).filter(User.status == UserStatus.active).scalar(),
        "blocked_users": db.query(func.count(User.id)).filter(User.status == UserStatus.blocked).scalar(),
        "total_listings": db.query(func.count(Listing.id)).scalar(),
        "pending_listings": db.query(func.count(Listing.id)).filter(Listing.status == ListingStatus.pending_review).scalar(),
        "approved_listings": db.query(func.count(Listing.id)).filter(Listing.status == ListingStatus.approved).scalar(),
        "rejected_listings": db.query(func.count(Listing.id)).filter(Listing.status == ListingStatus.rejected).scalar(),
        "total_conversations": db.query(func.count(Conversation.id)).scalar(),
        "total_messages": db.query(func.count(Message.id)).scalar(),
        "open_reports": db.query(func.count(Report.id)).filter(Report.status == ReportStatus.pending).scalar(),
        "total_payments": db.query(func.count(Payment.id)).scalar(),
        "total_revenue": db.query(func.coalesce(func.sum(Payment.amount), 0)).filter(Payment.status == PaymentStatus.successful).scalar(),
        "active_promotions": db.query(func.count(Promotion.id)).filter(
            Promotion.status == PromotionStatus.active,
            Promotion.ends_at > datetime.utcnow(),
        ).scalar(),
    }

    return templates.TemplateResponse(request, "admin/dashboard.html", {
        "admin": admin,
        "stats": stats,
        "flash": get_flash(request),
        "now": datetime.utcnow(),
    })


# ─────────────────────────────────────────────
# Users
# ─────────────────────────────────────────────

@router.get("/users", response_class=HTMLResponse)
def users_list(
    request: Request,
    q: str = "",
    page: int = 1,
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    page_size = 20
    query = db.query(User)
    if q:
        query = query.filter(
            or_(User.email.ilike(f"%{q}%"), User.full_name.ilike(f"%{q}%"))
        )
    total = query.count()
    users = query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    total_pages = (total + page_size - 1) // page_size

    return templates.TemplateResponse(request, "admin/users.html", {
        "admin": admin,
        "users": users,
        "q": q,
        "page": page,
        "total_pages": total_pages,
        "total": total,
        "flash": get_flash(request),
    })


@router.get("/users/{user_id}", response_class=HTMLResponse)
def user_detail(request: Request, user_id: int, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        flash(request, "Пользователь не найден", "danger")
        return RedirectResponse("/admin/users", status_code=302)

    listings = db.query(Listing).filter(Listing.owner_id == user_id).order_by(Listing.created_at.desc()).limit(10).all()
    payments = db.query(Payment).filter(Payment.user_id == user_id).order_by(Payment.created_at.desc()).limit(10).all()
    reports_filed = db.query(Report).filter(Report.reporter_user_id == user_id).order_by(Report.created_at.desc()).limit(10).all()

    return templates.TemplateResponse(request, "admin/user_detail.html", {
        "admin": admin,
        "user": user,
        "listings": listings,
        "payments": payments,
        "reports_filed": reports_filed,
        "flash": get_flash(request),
        "now": datetime.utcnow(),
    })


@router.post("/users/{user_id}/suspend")
def suspend_user(
    request: Request,
    user_id: int,
    note: str = Form(""),
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.status = UserStatus.blocked
        user.blocked_until = datetime.utcnow() + timedelta(days=7)
        db.commit()
        log_action(db, admin.id, "user_suspended", "user", user_id, note or "Заблокирован на 7 дней")
        flash(request, f"Пользователь {user.email} заблокирован на 7 дней")
    return RedirectResponse(f"/admin/users/{user_id}", status_code=302)


@router.post("/users/{user_id}/unsuspend")
def unsuspend_user(request: Request, user_id: int, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    user = db.query(User).filter(User.id == user_id).first()
    if user:
        user.status = UserStatus.active
        user.blocked_until = None
        db.commit()
        log_action(db, admin.id, "user_unsuspended", "user", user_id)
        flash(request, f"Пользователь {user.email} разблокирован")
    return RedirectResponse(f"/admin/users/{user_id}", status_code=302)


# ─────────────────────────────────────────────
# Listings
# ─────────────────────────────────────────────

@router.get("/listings", response_class=HTMLResponse)
def listings_list(
    request: Request,
    status: str = "pending_review",
    category_id: int = None,
    city: str = "",
    page: int = 1,
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    page_size = 20
    query = db.query(Listing)
    if status and status != "all":
        try:
            query = query.filter(Listing.status == ListingStatus(status))
        except ValueError:
            pass
    if category_id:
        query = query.filter(Listing.category_id == category_id)
    if city:
        query = query.filter(Listing.city.ilike(f"%{city}%"))

    total = query.count()
    listings = query.order_by(Listing.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    total_pages = (total + page_size - 1) // page_size
    categories = db.query(Category).filter(Category.is_active == True).all()

    return templates.TemplateResponse(request, "admin/listings.html", {
        "admin": admin,
        "listings": listings,
        "status_filter": status,
        "category_id": category_id,
        "city": city,
        "page": page,
        "total_pages": total_pages,
        "total": total,
        "categories": categories,
        "flash": get_flash(request),
    })


@router.get("/listings/{listing_id}", response_class=HTMLResponse)
def listing_detail(request: Request, listing_id: int, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        flash(request, "Объявление не найдено", "danger")
        return RedirectResponse("/admin/listings", status_code=302)

    owner = db.query(User).filter(User.id == listing.owner_id).first()
    reports = db.query(Report).filter(
        Report.target_type == "listing", Report.target_id == listing_id
    ).all()

    return templates.TemplateResponse(request, "admin/listing_detail.html", {
        "admin": admin,
        "listing": listing,
        "owner": owner,
        "reports": reports,
        "flash": get_flash(request),
    })


@router.post("/listings/{listing_id}/approve")
def approve_listing(request: Request, listing_id: int, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if listing:
        listing.status = ListingStatus.approved
        listing.published_at = datetime.utcnow()
        db.commit()
        log_action(db, admin.id, "listing_approved", "listing", listing_id)
        flash(request, "Объявление одобрено ✓")
    return RedirectResponse(f"/admin/listings/{listing_id}", status_code=302)


@router.post("/listings/{listing_id}/reject")
def reject_listing(
    request: Request,
    listing_id: int,
    note: str = Form(""),
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if listing:
        listing.status = ListingStatus.rejected
        listing.moderation_note = note
        db.commit()
        log_action(db, admin.id, "listing_rejected", "listing", listing_id, note)
        flash(request, "Объявление отклонено", "warning")
    return RedirectResponse(f"/admin/listings/{listing_id}", status_code=302)


@router.post("/listings/{listing_id}/archive")
def archive_listing(request: Request, listing_id: int, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if listing:
        listing.status = ListingStatus.archived
        db.commit()
        log_action(db, admin.id, "listing_archived", "listing", listing_id)
        flash(request, "Объявление архивировано", "secondary")
    return RedirectResponse(f"/admin/listings/{listing_id}", status_code=302)


# ─────────────────────────────────────────────
# Reports
# ─────────────────────────────────────────────

@router.get("/reports", response_class=HTMLResponse)
def reports_list(
    request: Request,
    status: str = "pending",
    reason: str = "",
    page: int = 1,
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    page_size = 20
    query = db.query(Report)
    if status and status != "all":
        try:
            query = query.filter(Report.status == ReportStatus(status))
        except ValueError:
            pass
    if reason:
        query = query.filter(Report.reason_code == reason)

    total = query.count()
    reports = query.order_by(Report.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    total_pages = (total + page_size - 1) // page_size

    return templates.TemplateResponse(request, "admin/reports.html", {
        "admin": admin,
        "reports": reports,
        "status_filter": status,
        "reason": reason,
        "page": page,
        "total_pages": total_pages,
        "total": total,
        "flash": get_flash(request),
    })


@router.post("/reports/{report_id}/resolve")
def resolve_report(
    request: Request,
    report_id: int,
    note: str = Form(""),
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    report = db.query(Report).filter(Report.id == report_id).first()
    if report:
        report.status = ReportStatus.resolved
        report.resolution_note = note
        report.reviewed_by_admin_id = admin.id
        report.reviewed_at = datetime.utcnow()
        db.commit()
        log_action(db, admin.id, "report_resolved", "report", report_id, note)
        flash(request, "Репорт закрыт как решённый")
    return RedirectResponse("/admin/reports", status_code=302)


@router.post("/reports/{report_id}/dismiss")
def dismiss_report(request: Request, report_id: int, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    report = db.query(Report).filter(Report.id == report_id).first()
    if report:
        report.status = ReportStatus.dismissed
        report.reviewed_by_admin_id = admin.id
        report.reviewed_at = datetime.utcnow()
        db.commit()
        log_action(db, admin.id, "report_dismissed", "report", report_id)
        flash(request, "Репорт отклонён", "secondary")
    return RedirectResponse("/admin/reports", status_code=302)


# ─────────────────────────────────────────────
# Categories
# ─────────────────────────────────────────────

@router.get("/categories", response_class=HTMLResponse)
def categories_list(request: Request, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    categories = db.query(Category).order_by(Category.display_order).all()
    return templates.TemplateResponse(request, "admin/categories.html", {
        "admin": admin,
        "categories": categories,
        "flash": get_flash(request),
    })


@router.post("/categories/create")
def create_category(
    request: Request,
    name_en: str = Form(...),
    name_ru: str = Form(...),
    slug: str = Form(...),
    display_order: int = Form(0),
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    cat = Category(name_en=name_en, name_ru=name_ru, slug=slug, display_order=display_order, is_active=True)
    db.add(cat)
    db.commit()
    log_action(db, admin.id, "category_created", "category", cat.id, name_en)
    flash(request, f"Категория «{name_en}» создана")
    return RedirectResponse("/admin/categories", status_code=302)


@router.post("/categories/{cat_id}/toggle")
def toggle_category(request: Request, cat_id: int, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    cat = db.query(Category).filter(Category.id == cat_id).first()
    if cat:
        cat.is_active = not cat.is_active
        db.commit()
        action = "category_enabled" if cat.is_active else "category_disabled"
        log_action(db, admin.id, action, "category", cat_id)
        flash(request, f"Категория {'включена' if cat.is_active else 'выключена'}")
    return RedirectResponse("/admin/categories", status_code=302)


@router.post("/categories/{cat_id}/edit")
def edit_category(
    request: Request,
    cat_id: int,
    name_en: str = Form(...),
    name_ru: str = Form(...),
    display_order: int = Form(0),
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    cat = db.query(Category).filter(Category.id == cat_id).first()
    if cat:
        cat.name_en = name_en
        cat.name_ru = name_ru
        cat.display_order = display_order
        db.commit()
        log_action(db, admin.id, "category_edited", "category", cat_id, name_en)
        flash(request, "Категория обновлена")
    return RedirectResponse("/admin/categories", status_code=302)


# ─────────────────────────────────────────────
# Promotions
# ─────────────────────────────────────────────

@router.get("/promotions", response_class=HTMLResponse)
def promotions_list(request: Request, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    packages = db.query(PromotionPackage).all()
    active_promos = db.query(Promotion).filter(
        Promotion.status == PromotionStatus.active
    ).order_by(Promotion.ends_at).limit(50).all()
    expired_promos = db.query(Promotion).filter(
        Promotion.status != PromotionStatus.active
    ).order_by(Promotion.ends_at.desc()).limit(20).all()

    return templates.TemplateResponse(request, "admin/promotions.html", {
        "admin": admin,
        "packages": packages,
        "active_promos": active_promos,
        "expired_promos": expired_promos,
        "flash": get_flash(request),
    })


@router.post("/promotions/packages/create")
def create_package(
    request: Request,
    name_en: str = Form(...),
    name_ru: str = Form(...),
    price: float = Form(...),
    duration_days: int = Form(...),
    promotion_type: str = Form("featured"),
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    from app.models.promotion_package import PromotionType
    pkg = PromotionPackage(
        name_en=name_en,
        name_ru=name_ru,
        price=price,
        duration_days=duration_days,
        promotion_type=PromotionType(promotion_type),
    )
    db.add(pkg)
    db.commit()
    log_action(db, admin.id, "package_created", "promotion_package", pkg.id, name_en)
    flash(request, f"Пакет «{name_en}» создан")
    return RedirectResponse("/admin/promotions", status_code=302)


@router.post("/promotions/{promo_id}/deactivate")
def deactivate_promo(request: Request, promo_id: int, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    promo = db.query(Promotion).filter(Promotion.id == promo_id).first()
    if promo:
        promo.status = PromotionStatus.cancelled
        db.commit()
        log_action(db, admin.id, "promotion_deactivated", "promotion", promo_id)
        flash(request, "Промо деактивировано", "warning")
    return RedirectResponse("/admin/promotions", status_code=302)


# ─────────────────────────────────────────────
# Payments
# ─────────────────────────────────────────────

@router.get("/payments", response_class=HTMLResponse)
def payments_list(
    request: Request,
    status: str = "all",
    page: int = 1,
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    page_size = 25
    query = db.query(Payment)
    if status and status != "all":
        try:
            query = query.filter(Payment.status == PaymentStatus(status))
        except ValueError:
            pass

    total = query.count()
    payments = query.order_by(Payment.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    total_pages = (total + page_size - 1) // page_size

    return templates.TemplateResponse(request, "admin/payments.html", {
        "admin": admin,
        "payments": payments,
        "status_filter": status,
        "page": page,
        "total_pages": total_pages,
        "total": total,
        "flash": get_flash(request),
    })


# ─────────────────────────────────────────────
# Audit Log
# ─────────────────────────────────────────────

@router.get("/audit-log", response_class=HTMLResponse)
def audit_log(request: Request, page: int = 1, db: Session = Depends(get_db)):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    page_size = 30
    total = db.query(func.count(AuditLog.id)).scalar()
    logs = db.query(AuditLog).order_by(AuditLog.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()
    total_pages = (total + page_size - 1) // page_size

    return templates.TemplateResponse(request, "admin/audit_log.html", {
        "admin": admin,
        "logs": logs,
        "page": page,
        "total_pages": total_pages,
        "total": total,
    })


# ─────────────────────────────────────────────
# Conversation Inspection (ТЗ 20.5)
# ─────────────────────────────────────────────

@router.get("/conversations/{conversation_id}", response_class=HTMLResponse)
def inspect_conversation(
    request: Request,
    conversation_id: int,
    page: int = 1,
    db: Session = Depends(get_db),
):
    admin = get_admin_user(request, db)
    if not admin:
        return RedirectResponse("/admin/login", status_code=302)

    conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not conv:
        flash(request, "Беседа не найдена", "danger")
        return RedirectResponse("/admin/reports", status_code=302)

    participant_a = db.query(User).filter(User.id == conv.participant_a_id).first()
    participant_b = db.query(User).filter(User.id == conv.participant_b_id).first()

    page_size = 50
    total = db.query(func.count(Message.id)).filter(Message.conversation_id == conversation_id).scalar()
    messages = db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).order_by(Message.sent_at.asc()).offset((page - 1) * page_size).limit(page_size).all()
    total_pages = (total + page_size - 1) // page_size

    log_action(db, admin.id, "inspect_conversation", "conversation", conversation_id)

    return templates.TemplateResponse(request, "admin/conversation_detail.html", {
        "admin": admin,
        "conversation": conv,
        "participant_a": participant_a,
        "participant_b": participant_b,
        "messages": messages,
        "page": page,
        "total_pages": total_pages,
        "total": total,
        "flash": get_flash(request),
    })
