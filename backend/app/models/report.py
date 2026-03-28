import enum
from datetime import datetime

from sqlalchemy import String, Text, Enum, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TargetType(str, enum.Enum):
    listing = "listing"
    user = "user"
    message = "message"


class ReasonCode(str, enum.Enum):
    spam = "spam"
    fake = "fake"
    scam = "scam"
    duplicate = "duplicate"
    offensive = "offensive"
    prohibited = "prohibited"
    harassment = "harassment"
    other = "other"


class ReportStatus(str, enum.Enum):
    pending = "pending"
    resolved = "resolved"
    dismissed = "dismissed"


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    reporter_user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    target_type: Mapped[TargetType] = mapped_column(Enum(TargetType), nullable=False)
    target_id: Mapped[int] = mapped_column(nullable=False)
    reason_code: Mapped[ReasonCode] = mapped_column(Enum(ReasonCode), nullable=False)
    reason_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[ReportStatus] = mapped_column(Enum(ReportStatus), default=ReportStatus.pending, index=True)
    resolution_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewed_by_admin_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, server_default=func.now())
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    reporter = relationship("User", foreign_keys=[reporter_user_id], lazy="joined")
    reviewer = relationship("User", foreign_keys=[reviewed_by_admin_id], lazy="joined")
