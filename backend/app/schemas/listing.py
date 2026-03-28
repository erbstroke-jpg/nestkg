from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, Field


class ListingMediaOut(BaseModel):
    id: int
    file_url: str
    original_name: str
    mime_type: str
    display_order: int
    is_primary: bool

    class Config:
        from_attributes = True


class ListingOwnerOut(BaseModel):
    id: int
    full_name: str
    profile_image_url: str | None = None
    city: str | None = None

    class Config:
        from_attributes = True


class CategoryOut(BaseModel):
    id: int
    name_en: str
    name_ru: str
    slug: str
    icon_url: str | None = None
    parent_id: int | None = None
    display_order: int
    attributes_schema: dict | None = None

    class Config:
        from_attributes = True


class ListingOut(BaseModel):
    id: int
    owner_id: int
    category_id: int
    title: str
    description: str
    price: Decimal
    currency: str
    city: str
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    condition: str | None = None
    is_negotiable: bool
    contact_preference: str
    status: str
    view_count: int
    attributes_json: dict | None = None
    created_at: datetime
    updated_at: datetime
    published_at: datetime | None = None
    media: list[ListingMediaOut] = []
    owner: ListingOwnerOut | None = None
    category: CategoryOut | None = None
    is_favorited: bool = False
    is_promoted: bool = False

    class Config:
        from_attributes = True


class ListingCreateRequest(BaseModel):
    category_id: int
    title: str = Field(..., min_length=3, max_length=200)
    description: str = Field(..., min_length=10)
    price: Decimal = Field(..., ge=0)
    currency: str = Field("USD", max_length=3)
    city: str = Field(..., min_length=1, max_length=100)
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    condition: str | None = None
    is_negotiable: bool = False
    contact_preference: str = "chat"
    attributes_json: dict | None = None
    submit_for_review: bool = False


class ListingUpdateRequest(BaseModel):
    category_id: int | None = None
    title: str | None = Field(None, min_length=3, max_length=200)
    description: str | None = Field(None, min_length=10)
    price: Decimal | None = Field(None, ge=0)
    currency: str | None = Field(None, max_length=3)
    city: str | None = Field(None, max_length=100)
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    condition: str | None = None
    is_negotiable: bool | None = None
    contact_preference: str | None = None
    attributes_json: dict | None = None
    submit_for_review: bool | None = None


class PaginatedListings(BaseModel):
    items: list[ListingOut]
    page: int
    page_size: int
    total_items: int
    total_pages: int
