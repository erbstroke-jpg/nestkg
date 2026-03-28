from datetime import datetime
from pydantic import BaseModel


class NotificationOut(BaseModel):
    id: int
    type: str
    title: str
    body: str | None = None
    reference_type: str | None = None
    reference_id: int | None = None
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True
