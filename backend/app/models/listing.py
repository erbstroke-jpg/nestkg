import enum
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    String, Text, Integer, Numeric, Boolean, Enum, DateTime, JSON, ForeignKey, func
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ListingStatus(str, enum.Enum):
    draft = "draft"
    pending_review = "pending_review"
    approved = "approved"
    rejected = "rejected"
    archived = "archived"
    sold = "sold"


class ListingCondition(str, enum.Enum):
    new_building = "new_building"
    secondary = "secondary"
    needs_renovation = "needs_renovation"
    under_construction = "under_construction"
    renovated = "renovated"


class ContactPreference(str, enum.Enum):
    chat = "chat"
    phone = "phone"
    both = "both"


class Listing(Base):
    __tablename__ = "listings"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="USD")
    city: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(10, 7), nullable=True)
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(10, 7), nullable=True)
    condition: Mapped[ListingCondition | None] = mapped_column(Enum(ListingCondition), nullable=True)
    is_negotiable: Mapped[bool] = mapped_column(Boolean, default=False)
    contact_preference: Mapped[ContactPreference] = mapped_column(
        Enum(ContactPreference), default=ContactPreference.chat
    )
    status: Mapped[ListingStatus] = mapped_column(
        Enum(ListingStatus), default=ListingStatus.draft, nullable=False, index=True
    )
    moderation_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    view_count: Mapped[int] = mapped_column(Integer, default=0)
    attributes_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())
    published_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    # Relationships
    owner = relationship("User", back_populates="listings", lazy="joined")
    category = relationship("Category", back_populates="listings", lazy="joined")
    media = relationship("ListingMedia", back_populates="listing", lazy="selectin", order_by="ListingMedia.display_order")
    favorites = relationship("Favorite", back_populates="listing", lazy="dynamic")
    promotions = relationship("Promotion", back_populates="listing", lazy="dynamic")
