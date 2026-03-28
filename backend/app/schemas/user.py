from datetime import datetime
from pydantic import BaseModel, EmailStr, Field


class UserOut(BaseModel):
    id: int
    full_name: str
    email: EmailStr
    phone: str | None = None
    role: str
    status: str
    profile_image_url: str | None = None
    bio: str | None = None
    city: str | None = None
    preferred_language: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UserPublicOut(BaseModel):
    id: int
    full_name: str
    profile_image_url: str | None = None
    bio: str | None = None
    city: str | None = None
    created_at: datetime
    active_listings_count: int = 0

    class Config:
        from_attributes = True


class UserUpdateRequest(BaseModel):
    full_name: str | None = Field(None, min_length=2, max_length=100)
    phone: str | None = Field(None, max_length=20)
    bio: str | None = Field(None, max_length=1000)
    city: str | None = Field(None, max_length=100)
    preferred_language: str | None = None
