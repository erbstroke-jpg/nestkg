from datetime import datetime
from pydantic import BaseModel, Field


class ReportCreateRequest(BaseModel):
    target_type: str  # listing, user, message
    target_id: int
    reason_code: str
    reason_text: str | None = Field(None, max_length=1000)


class ReportOut(BaseModel):
    id: int
    reporter_user_id: int
    target_type: str
    target_id: int
    reason_code: str
    reason_text: str | None = None
    status: str
    resolution_note: str | None = None
    reviewed_by_admin_id: int | None = None
    created_at: datetime
    reviewed_at: datetime | None = None

    class Config:
        from_attributes = True
