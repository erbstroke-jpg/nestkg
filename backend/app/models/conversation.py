from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    listing_id: Mapped[int | None] = mapped_column(ForeignKey("listings.id"), nullable=True, index=True)
    participant_a_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    participant_b_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    participant_a = relationship("User", foreign_keys=[participant_a_id], lazy="joined")
    participant_b = relationship("User", foreign_keys=[participant_b_id], lazy="joined")
    listing = relationship("Listing", lazy="joined")
    messages = relationship("Message", back_populates="conversation", lazy="dynamic", order_by="Message.sent_at")
