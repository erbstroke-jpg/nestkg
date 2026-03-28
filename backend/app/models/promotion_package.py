import enum
from datetime import datetime
from decimal import Decimal

from sqlalchemy import String, Integer, Numeric, Boolean, Enum, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PromotionType(str, enum.Enum):
    featured = "featured"
    boosted = "boosted"
    top_of_feed = "top_of_feed"


class PromotionPackage(Base):
    __tablename__ = "promotion_packages"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name_en: Mapped[str] = mapped_column(String(100), nullable=False)
    name_ru: Mapped[str] = mapped_column(String(100), nullable=False)
    promotion_type: Mapped[PromotionType] = mapped_column(Enum(PromotionType), nullable=False)
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="USD")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
