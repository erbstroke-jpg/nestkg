from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.models.user import User, UserStatus, UserRole
from app.models.listing import Listing, ListingStatus
from app.models.conversation import Conversation
from app.models.message import Message
from app.models.report import Report, ReportStatus
from app.models.payment import Payment, PaymentStatus
from app.models.promotion import Promotion, PromotionStatus
from app.models.promotion_package import PromotionPackage
from app.models.category import Category
from app.models.notification import Notification, NotificationType
from app.models.audit_log import AuditLog
from app.dependencies.auth import require_admin
from app.dependencies.pagination import get_pagination, PaginationParams, paginated_response

router = APIRouter(prefix="/admin", tags=["Admin"])


# ── helpers ──────────────────────────────────────────

def _log_action(db: Session, admin: User, action: str, target_type: str, target_id: int, details: dict | None = None):
    log = AuditLog(
        admin_id=admin.id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        details_json=details,
    )
    db.add(log)


# ── Dashboard ────────────────────────────────────────

@router.get("/dashboard")
def dashboard(admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    return {
        "users": {
            "total": db.query(func.count(User.id)).scalar(),
            "active": db.query(func.count(User.id)).filter(User.status == UserStatus.active).scalar(),
            "blocked": db.query(func.count(User.id)).filter(User.status == UserStatus.blocked).scalar(),
        },
        "listings": {
            "total": db.query(func.count(Listing.id)).scalar(),
            "pending": db.query(func.count(Listing.id)).filter(Listing.status == ListingStatus.pending_review).scalar(),
            "approved": db.query(func.count(Listing.id)).filter(Listing.status == ListingStatus.approved).scalar(),
            "rejected": db.query(func.count(Listing.id)).filter(Listing.status == ListingStatus.rejected).scalar(),
        },
        "conversations_total": db.query(func.count(Conversation.id)).scalar(),
        "messages_total": db.query(func.count(Message.id)).scalar(),
        "reports": {
            "total": db.query(func.count(Report.id)).scalar(),
            "pending": db.query(func.count(Report.id)).filter(Report.status == ReportStatus.pending).scalar(),
        },
        "payments": {
            "total": db.query(func.count(Payment.id)).scalar(),
            "revenue": float(
                db.query(func.coalesce(func.sum(Payment.amount), 0))
                .filter(Payment.status == PaymentStatus.successful)
                .scalar()
            ),
        },
        "promotions": {
            "active": db.query(func.count(Promotion.id)).filter(Promotion.status == PromotionStatus.active).scalar(),
        },
    }


# ── User Management ──────────────────────────────────

@router.get("/users")
def list_users(
    search: str | None = None,
    status_filter: str | None = None,
    pagination: PaginationParams = Depends(get_pagination),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(User)
    if search:
        term = f"%{search}%"
        query = query.filter(User.full_name.ilike(term) | User.email.ilike(term))
    if status_filter:
        query = query.filter(User.status == status_filter)
    query = query.order_by(User.created_at.desc())

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    from app.schemas.user import UserOut
    return paginated_response([UserOut.model_validate(u) for u in items], total, pagination)


@router.get("/users/{user_id}")
def get_user_detail(user_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    from app.schemas.user import UserOut
    return UserOut.model_validate(user)


@router.put("/users/{user_id}/block")
def block_user(
    user_id: int,
    days: int = Query(7, ge=1, le=365),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role == UserRole.admin:
        raise HTTPException(status_code=400, detail="Cannot block admin")

    user.status = UserStatus.blocked
    user.blocked_until = datetime.now(timezone.utc) + timedelta(days=days)
    _log_action(db, admin, "block_user", "user", user_id, {"days": days})
    db.commit()
    return {"message": f"User blocked for {days} days"}


@router.put("/users/{user_id}/unblock")
def unblock_user(user_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.status = UserStatus.active
    user.blocked_until = None
    _log_action(db, admin, "unblock_user", "user", user_id)
    db.commit()
    return {"message": "User unblocked"}


# ── Listings Moderation ──────────────────────────────

@router.get("/listings")
def admin_list_listings(
    status_filter: str | None = None,
    category_id: int | None = None,
    city: str | None = None,
    pagination: PaginationParams = Depends(get_pagination),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Listing).options(
        joinedload(Listing.owner), joinedload(Listing.category)
    )
    if status_filter:
        query = query.filter(Listing.status == status_filter)
    if category_id:
        query = query.filter(Listing.category_id == category_id)
    if city:
        query = query.filter(Listing.city.ilike(f"%{city}%"))
    query = query.order_by(Listing.created_at.desc())

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    from app.schemas.listing import ListingOut
    return paginated_response([ListingOut.model_validate(i) for i in items], total, pagination)


@router.put("/listings/{listing_id}/approve")
def approve_listing(listing_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.status != ListingStatus.pending_review:
        raise HTTPException(status_code=400, detail=f"Cannot approve from status '{listing.status.value}'")

    listing.status = ListingStatus.approved
    listing.published_at = datetime.now(timezone.utc)
    _log_action(db, admin, "approve_listing", "listing", listing_id)

    # Notify owner
    notif = Notification(
        user_id=listing.owner_id,
        type=NotificationType.listing_approved,
        title="Listing approved",
        body=f'Your listing "{listing.title}" has been approved.',
        reference_type="listing",
        reference_id=listing.id,
    )
    db.add(notif)
    db.commit()
    return {"message": "Listing approved"}


@router.put("/listings/{listing_id}/reject")
def reject_listing(
    listing_id: int,
    note: str = Query("", max_length=500),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    listing.status = ListingStatus.rejected
    listing.moderation_note = note
    _log_action(db, admin, "reject_listing", "listing", listing_id, {"note": note})

    notif = Notification(
        user_id=listing.owner_id,
        type=NotificationType.listing_rejected,
        title="Listing rejected",
        body=f'Your listing "{listing.title}" was rejected. Reason: {note or "N/A"}',
        reference_type="listing",
        reference_id=listing.id,
    )
    db.add(notif)
    db.commit()
    return {"message": "Listing rejected"}


# ── Reports Management ───────────────────────────────

@router.get("/reports")
def admin_list_reports(
    status_filter: str | None = None,
    pagination: PaginationParams = Depends(get_pagination),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Report).options(joinedload(Report.reporter))
    if status_filter:
        query = query.filter(Report.status == status_filter)
    query = query.order_by(Report.created_at.desc())

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    from app.schemas.report import ReportOut
    return paginated_response([ReportOut.model_validate(r) for r in items], total, pagination)


@router.put("/reports/{report_id}/resolve")
def resolve_report(
    report_id: int,
    resolution_note: str = Query("", max_length=500),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    report.status = ReportStatus.resolved
    report.resolution_note = resolution_note
    report.reviewed_by_admin_id = admin.id
    report.reviewed_at = datetime.now(timezone.utc)
    _log_action(db, admin, "resolve_report", "report", report_id, {"note": resolution_note})
    db.commit()
    return {"message": "Report resolved"}


@router.put("/reports/{report_id}/dismiss")
def dismiss_report(report_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    report = db.query(Report).filter(Report.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    report.status = ReportStatus.dismissed
    report.reviewed_by_admin_id = admin.id
    report.reviewed_at = datetime.now(timezone.utc)
    _log_action(db, admin, "dismiss_report", "report", report_id)
    db.commit()
    return {"message": "Report dismissed"}


# ── Categories Management ────────────────────────────

@router.post("/categories")
def create_category(
    name_en: str = Query(...),
    name_ru: str = Query(...),
    slug: str = Query(...),
    display_order: int = Query(0),
    parent_id: int | None = None,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if db.query(Category).filter(Category.slug == slug).first():
        raise HTTPException(status_code=409, detail="Slug already exists")

    cat = Category(
        name_en=name_en, name_ru=name_ru, slug=slug,
        display_order=display_order, parent_id=parent_id,
    )
    db.add(cat)
    _log_action(db, admin, "create_category", "category", 0)
    db.commit()
    db.refresh(cat)

    from app.schemas.listing import CategoryOut
    return CategoryOut.model_validate(cat)


@router.put("/categories/{category_id}")
def update_category(
    category_id: int,
    name_en: str | None = None,
    name_ru: str | None = None,
    is_active: bool | None = None,
    display_order: int | None = None,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    cat = db.query(Category).filter(Category.id == category_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")

    if name_en is not None:
        cat.name_en = name_en
    if name_ru is not None:
        cat.name_ru = name_ru
    if is_active is not None:
        cat.is_active = is_active
    if display_order is not None:
        cat.display_order = display_order

    _log_action(db, admin, "update_category", "category", category_id)
    db.commit()
    db.refresh(cat)

    from app.schemas.listing import CategoryOut
    return CategoryOut.model_validate(cat)


# ── Payments Management ──────────────────────────────

@router.get("/payments")
def admin_list_payments(
    status_filter: str | None = None,
    pagination: PaginationParams = Depends(get_pagination),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Payment).options(joinedload(Payment.user))
    if status_filter:
        query = query.filter(Payment.status == status_filter)
    query = query.order_by(Payment.created_at.desc())

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    from app.schemas.payment import PaymentOut
    return paginated_response([PaymentOut.model_validate(p) for p in items], total, pagination)


# ── Promotions Management ────────────────────────────

@router.get("/promotions")
def admin_list_promotions(
    status_filter: str | None = None,
    pagination: PaginationParams = Depends(get_pagination),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Promotion).options(
        joinedload(Promotion.listing), joinedload(Promotion.user)
    )
    if status_filter:
        query = query.filter(Promotion.status == status_filter)
    query = query.order_by(Promotion.created_at.desc())

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    from app.schemas.payment import PromotionOut
    return paginated_response([PromotionOut.model_validate(p) for p in items], total, pagination)


@router.put("/promotions/{promo_id}/deactivate")
def deactivate_promotion(promo_id: int, admin: User = Depends(require_admin), db: Session = Depends(get_db)):
    promo = db.query(Promotion).filter(Promotion.id == promo_id).first()
    if not promo:
        raise HTTPException(status_code=404, detail="Promotion not found")

    promo.status = PromotionStatus.cancelled
    _log_action(db, admin, "deactivate_promotion", "promotion", promo_id)
    db.commit()
    return {"message": "Promotion deactivated"}


# ── Promotion Packages Management ────────────────────

@router.post("/promotion-packages")
def create_package(
    name_en: str = Query(...),
    name_ru: str = Query(...),
    promotion_type: str = Query(...),
    duration_days: int = Query(..., ge=1),
    price: float = Query(..., ge=0),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    pkg = PromotionPackage(
        name_en=name_en, name_ru=name_ru,
        promotion_type=promotion_type,
        duration_days=duration_days, price=price,
    )
    db.add(pkg)
    _log_action(db, admin, "create_promotion_package", "promotion_package", 0)
    db.commit()
    db.refresh(pkg)

    from app.schemas.payment import PromotionPackageOut
    return PromotionPackageOut.model_validate(pkg)


# ── Conversation Inspection (for abuse) ──────────────

@router.get("/conversations/{conversation_id}")
def inspect_conversation(
    conversation_id: int,
    pagination: PaginationParams = Depends(get_pagination),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    conv = db.query(Conversation).options(
        joinedload(Conversation.participant_a),
        joinedload(Conversation.participant_b),
    ).filter(Conversation.id == conversation_id).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")

    msgs = (
        db.query(Message)
        .options(joinedload(Message.attachments), joinedload(Message.sender))
        .filter(Message.conversation_id == conversation_id)
        .order_by(Message.sent_at.desc())
    )
    total = msgs.count()
    items = msgs.offset(pagination.offset).limit(pagination.page_size).all()

    _log_action(db, admin, "inspect_conversation", "conversation", conversation_id)
    db.commit()

    from app.schemas.messaging import MessageOut
    return {
        "conversation_id": conv.id,
        "listing_id": conv.listing_id,
        "participant_a": {"id": conv.participant_a.id, "full_name": conv.participant_a.full_name},
        "participant_b": {"id": conv.participant_b.id, "full_name": conv.participant_b.full_name},
        "messages": paginated_response(
            [MessageOut.model_validate(m) for m in items], total, pagination
        ),
    }


# ── Audit Logs ───────────────────────────────────────

@router.get("/audit-logs")
def list_audit_logs(
    pagination: PaginationParams = Depends(get_pagination),
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    query = db.query(AuditLog).options(joinedload(AuditLog.admin)).order_by(AuditLog.created_at.desc())
    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    return paginated_response(
        [
            {
                "id": log.id,
                "admin_name": log.admin.full_name,
                "action": log.action,
                "target_type": log.target_type,
                "target_id": log.target_id,
                "details": log.details_json,
                "created_at": log.created_at.isoformat(),
            }
            for log in items
        ],
        total,
        pagination,
    )
