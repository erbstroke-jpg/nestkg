from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel


# --- Promotion Packages ---

class PromotionPackageOut(BaseModel):
    id: int
    name_en: str
    name_ru: str
    promotion_type: str
    duration_days: int
    price: Decimal
    currency: str
    is_active: bool

    class Config:
        from_attributes = True


# --- Promotions ---

class PurchasePromotionRequest(BaseModel):
    listing_id: int
    package_id: int
    target_city: str | None = None
    target_category_id: int | None = None


class PromotionOut(BaseModel):
    id: int
    listing_id: int
    user_id: int
    package_id: int
    promotion_type: str
    target_city: str | None = None
    target_category_id: int | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    status: str
    purchased_price: Decimal
    payment_id: int | None = None
    created_at: datetime

    class Config:
        from_attributes = True


# --- Payments ---

class PaymentOut(BaseModel):
    id: int
    user_id: int
    listing_id: int | None = None
    amount: Decimal
    currency: str
    status: str
    payment_provider: str
    provider_reference: str | None = None
    created_at: datetime
    paid_at: datetime | None = None

    class Config:
        from_attributes = True


class ConfirmPaymentRequest(BaseModel):
    """Mock payment confirmation."""
    success: bool = True
