import enum
from datetime import datetime
from decimal import Decimal

from sqlalchemy import String, Numeric, Enum, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class PromotionStatus(str, enum.Enum):
    pending_payment = "pending_payment"
    active = "active"
    expired = "expired"
    cancelled = "cancelled"


class Promotion(Base):
    __tablename__ = "promotions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    listing_id: Mapped[int] = mapped_column(ForeignKey("listings.id"), nullable=False, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    package_id: Mapped[int] = mapped_column(ForeignKey("promotion_packages.id"), nullable=False)
    promotion_type: Mapped[str] = mapped_column(String(50), nullable=False)
    target_city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    target_category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"), nullable=True)
    starts_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    status: Mapped[PromotionStatus] = mapped_column(
        Enum(PromotionStatus), default=PromotionStatus.pending_payment, index=True
    )
    purchased_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    payment_id: Mapped[int | None] = mapped_column(ForeignKey("payments.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())

    listing = relationship("Listing", back_populates="promotions", lazy="joined")
    user = relationship("User", lazy="joined")
    package = relationship("PromotionPackage", lazy="joined")
    payment = relationship("Payment", lazy="joined")
