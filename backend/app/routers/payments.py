import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.listing import Listing, ListingStatus
from app.models.promotion_package import PromotionPackage
from app.models.promotion import Promotion, PromotionStatus
from app.models.payment import Payment, PaymentStatus
from app.models.notification import Notification, NotificationType
from app.schemas.payment import (
    PromotionPackageOut, PurchasePromotionRequest, PromotionOut,
    PaymentOut, ConfirmPaymentRequest,
)
from app.dependencies.auth import get_current_user
from app.dependencies.pagination import get_pagination, PaginationParams, paginated_response

router = APIRouter(tags=["Payments & Promotions"])


# ── Promotion Packages (public) ──────────────────────

@router.get("/promotion-packages", response_model=list[PromotionPackageOut])
def list_packages(db: Session = Depends(get_db)):
    return db.query(PromotionPackage).filter(PromotionPackage.is_active == True).all()


# ── Purchase Promotion Flow ──────────────────────────

@router.post("/promotions/purchase", response_model=PromotionOut, status_code=201)
def purchase_promotion(
    req: PurchasePromotionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Validate listing belongs to user and is approved
    listing = db.query(Listing).filter(
        Listing.id == req.listing_id,
        Listing.owner_id == current_user.id,
    ).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found or not yours")
    if listing.status != ListingStatus.approved:
        raise HTTPException(status_code=400, detail="Only approved listings can be promoted")

    # Validate package
    package = db.query(PromotionPackage).filter(
        PromotionPackage.id == req.package_id,
        PromotionPackage.is_active == True,
    ).first()
    if not package:
        raise HTTPException(status_code=404, detail="Promotion package not found")

    # Check no active promo on this listing
    existing = db.query(Promotion).filter(
        Promotion.listing_id == req.listing_id,
        Promotion.status == PromotionStatus.active,
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Listing already has an active promotion")

    # Create payment record
    payment = Payment(
        user_id=current_user.id,
        listing_id=req.listing_id,
        amount=package.price,
        currency=package.currency,
        status=PaymentStatus.pending,
        payment_provider="mock",
        provider_reference=f"mock_{uuid.uuid4().hex[:12]}",
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)

    # Create promotion (pending payment)
    promo = Promotion(
        listing_id=req.listing_id,
        user_id=current_user.id,
        package_id=package.id,
        promotion_type=package.promotion_type.value,
        target_city=req.target_city,
        target_category_id=req.target_category_id,
        status=PromotionStatus.pending_payment,
        purchased_price=package.price,
        payment_id=payment.id,
    )
    db.add(promo)
    db.commit()
    db.refresh(promo)

    return PromotionOut.model_validate(promo)


# ── Mock Payment Confirm ─────────────────────────────

@router.post("/payments/{payment_id}/confirm", response_model=PaymentOut)
def confirm_payment(
    payment_id: int,
    req: ConfirmPaymentRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payment = db.query(Payment).filter(
        Payment.id == payment_id,
        Payment.user_id == current_user.id,
    ).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    if payment.status != PaymentStatus.pending:
        raise HTTPException(status_code=400, detail=f"Payment is already {payment.status.value}")

    now = datetime.now(timezone.utc)

    if req.success:
        payment.status = PaymentStatus.successful
        payment.paid_at = now

        # Activate linked promotion
        promo = db.query(Promotion).filter(Promotion.payment_id == payment.id).first()
        if promo:
            package = db.query(PromotionPackage).filter(PromotionPackage.id == promo.package_id).first()
            promo.status = PromotionStatus.active
            promo.starts_at = now
            promo.ends_at = now + timedelta(days=package.duration_days if package else 7)

            # Notification
            notif = Notification(
                user_id=current_user.id,
                type=NotificationType.promo_activated,
                title="Promotion activated",
                body=f"Your listing promotion is now active until {promo.ends_at.strftime('%Y-%m-%d')}",
                reference_type="promotion",
                reference_id=promo.id,
            )
            db.add(notif)
    else:
        payment.status = PaymentStatus.failed
        # Cancel linked promotion
        promo = db.query(Promotion).filter(Promotion.payment_id == payment.id).first()
        if promo:
            promo.status = PromotionStatus.cancelled

    db.commit()
    db.refresh(payment)
    return PaymentOut.model_validate(payment)


# ── My payments ──────────────────────────────────────

@router.get("/payments/my")
def my_payments(
    pagination: PaginationParams = Depends(get_pagination),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = (
        db.query(Payment)
        .filter(Payment.user_id == current_user.id)
        .order_by(Payment.created_at.desc())
    )
    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()
    return paginated_response(
        [PaymentOut.model_validate(p) for p in items],
        total,
        pagination,
    )


# ── My promotions ────────────────────────────────────

@router.get("/promotions/my")
def my_promotions(
    pagination: PaginationParams = Depends(get_pagination),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = (
        db.query(Promotion)
        .filter(Promotion.user_id == current_user.id)
        .order_by(Promotion.created_at.desc())
    )
    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()
    return paginated_response(
        [PromotionOut.model_validate(p) for p in items],
        total,
        pagination,
    )
