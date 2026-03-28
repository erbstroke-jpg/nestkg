from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from sqlalchemy import or_, and_
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.models.user import User
from app.models.listing import Listing, ListingStatus
from app.models.listing_media import ListingMedia
from app.models.category import Category
from app.models.favorite import Favorite
from app.models.promotion import Promotion, PromotionStatus
from app.schemas.listing import (
    ListingOut, ListingCreateRequest, ListingUpdateRequest, ListingMediaOut,
)
from app.dependencies.auth import get_current_user, get_optional_user
from app.dependencies.pagination import get_pagination, PaginationParams, paginated_response
from app.utils.files import save_upload_file, delete_upload_file
from app.config import settings

router = APIRouter(prefix="/listings", tags=["Listings"])


# ── helpers ──────────────────────────────────────────

def _enrich_listing(listing: Listing, user: User | None, db: Session) -> ListingOut:
    out = ListingOut.model_validate(listing)
    if user:
        fav = db.query(Favorite).filter(
            Favorite.user_id == user.id, Favorite.listing_id == listing.id
        ).first()
        out.is_favorited = fav is not None
    # check active promotion
    now = datetime.now(timezone.utc)
    promo = db.query(Promotion).filter(
        Promotion.listing_id == listing.id,
        Promotion.status == PromotionStatus.active,
        Promotion.starts_at <= now,
        Promotion.ends_at >= now,
    ).first()
    out.is_promoted = promo is not None
    return out


# ── public feed ──────────────────────────────────────

@router.get("")
def list_listings(
    search: str | None = Query(None, max_length=200),
    category_id: int | None = None,
    city: str | None = None,
    min_price: Decimal | None = None,
    max_price: Decimal | None = None,
    condition: str | None = None,
    sort_by: str = Query("newest", pattern="^(newest|oldest|price_asc|price_desc)$"),
    pagination: PaginationParams = Depends(get_pagination),
    current_user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    query = db.query(Listing).options(
        joinedload(Listing.owner),
        joinedload(Listing.category),
        joinedload(Listing.media),
    ).filter(Listing.status == ListingStatus.approved)

    if search:
        term = f"%{search}%"
        query = query.filter(or_(Listing.title.ilike(term), Listing.description.ilike(term)))
    if category_id:
        query = query.filter(Listing.category_id == category_id)
    if city:
        query = query.filter(Listing.city.ilike(f"%{city}%"))
    if min_price is not None:
        query = query.filter(Listing.price >= min_price)
    if max_price is not None:
        query = query.filter(Listing.price <= max_price)
    if condition:
        query = query.filter(Listing.condition == condition)

    # Sorting
    sort_map = {
        "newest": Listing.created_at.desc(),
        "oldest": Listing.created_at.asc(),
        "price_asc": Listing.price.asc(),
        "price_desc": Listing.price.desc(),
    }
    query = query.order_by(sort_map.get(sort_by, Listing.created_at.desc()))

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()
    enriched = [_enrich_listing(i, current_user, db) for i in items]

    return paginated_response(enriched, total, pagination)


# ── listing detail ───────────────────────────────────

@router.get("/{listing_id}", response_model=ListingOut)
def get_listing(
    listing_id: int,
    current_user: User | None = Depends(get_optional_user),
    db: Session = Depends(get_db),
):
    listing = db.query(Listing).options(
        joinedload(Listing.owner),
        joinedload(Listing.category),
        joinedload(Listing.media),
    ).filter(Listing.id == listing_id).first()

    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    # non-owner can only see approved listings
    is_owner = current_user and current_user.id == listing.owner_id
    is_admin = current_user and current_user.role.value == "admin"
    if listing.status != ListingStatus.approved and not is_owner and not is_admin:
        raise HTTPException(status_code=404, detail="Listing not found")

    # bump view count
    listing.view_count += 1
    db.commit()

    return _enrich_listing(listing, current_user, db)


# ── my listings ──────────────────────────────────────

@router.get("/my/all")
def get_my_listings(
    status_filter: str | None = None,
    pagination: PaginationParams = Depends(get_pagination),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Listing).filter(Listing.owner_id == current_user.id)
    if status_filter:
        query = query.filter(Listing.status == status_filter)
    query = query.order_by(Listing.created_at.desc())

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    return paginated_response(
        [ListingOut.model_validate(i) for i in items],
        total,
        pagination,
    )


# ── create ───────────────────────────────────────────

@router.post("", response_model=ListingOut, status_code=status.HTTP_201_CREATED)
def create_listing(
    req: ListingCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Validate category
    cat = db.query(Category).filter(Category.id == req.category_id, Category.is_active == True).first()
    if not cat:
        raise HTTPException(status_code=400, detail="Invalid or inactive category")

    initial_status = ListingStatus.pending_review if req.submit_for_review else ListingStatus.draft

    listing = Listing(
        owner_id=current_user.id,
        category_id=req.category_id,
        title=req.title,
        description=req.description,
        price=req.price,
        currency=req.currency,
        city=req.city,
        latitude=req.latitude,
        longitude=req.longitude,
        condition=req.condition,
        is_negotiable=req.is_negotiable,
        contact_preference=req.contact_preference,
        attributes_json=req.attributes_json,
        status=initial_status,
        published_at=datetime.now(timezone.utc) if initial_status == ListingStatus.pending_review else None,
    )
    db.add(listing)
    db.commit()
    db.refresh(listing)
    return ListingOut.model_validate(listing)


# ── update ───────────────────────────────────────────

@router.put("/{listing_id}", response_model=ListingOut)
def update_listing(
    listing_id: int,
    req: ListingUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.owner_id != current_user.id and current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Not your listing")

    update_data = req.model_dump(exclude_unset=True)

    # If re-submitting for review
    if update_data.pop("submit_for_review", None):
        if listing.status in (ListingStatus.draft, ListingStatus.rejected):
            listing.status = ListingStatus.pending_review
            listing.published_at = datetime.now(timezone.utc)

    if "category_id" in update_data:
        cat = db.query(Category).filter(Category.id == update_data["category_id"], Category.is_active == True).first()
        if not cat:
            raise HTTPException(status_code=400, detail="Invalid category")

    for field, value in update_data.items():
        setattr(listing, field, value)

    db.commit()
    db.refresh(listing)
    return ListingOut.model_validate(listing)


# ── delete (soft) ────────────────────────────────────

@router.delete("/{listing_id}")
def delete_listing(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.owner_id != current_user.id and current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Not your listing")

    listing.status = ListingStatus.archived
    db.commit()
    return {"message": "Listing archived"}


# ── status changes (owner) ──────────────────────────

@router.post("/{listing_id}/submit")
def submit_for_review(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    listing = db.query(Listing).filter(Listing.id == listing_id, Listing.owner_id == current_user.id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.status not in (ListingStatus.draft, ListingStatus.rejected):
        raise HTTPException(status_code=400, detail=f"Cannot submit from status '{listing.status.value}'")
    listing.status = ListingStatus.pending_review
    listing.published_at = datetime.now(timezone.utc)
    db.commit()
    return {"message": "Submitted for review"}


@router.post("/{listing_id}/mark-sold")
def mark_sold(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    listing = db.query(Listing).filter(Listing.id == listing_id, Listing.owner_id == current_user.id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.status != ListingStatus.approved:
        raise HTTPException(status_code=400, detail="Only approved listings can be marked as sold")
    listing.status = ListingStatus.sold
    db.commit()
    return {"message": "Listing marked as sold"}


# ── media ────────────────────────────────────────────

@router.post("/{listing_id}/media", response_model=ListingMediaOut, status_code=201)
async def upload_listing_media(
    listing_id: int,
    file: UploadFile = File(...),
    is_primary: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    if listing.owner_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your listing")

    # Check image count limit (max 10)
    count = db.query(ListingMedia).filter(ListingMedia.listing_id == listing_id).count()
    if count >= 10:
        raise HTTPException(status_code=400, detail="Maximum 10 images per listing")

    result = await save_upload_file(file, "listings", settings.allowed_image_types_list)

    # If primary, unset others
    if is_primary:
        db.query(ListingMedia).filter(ListingMedia.listing_id == listing_id).update({"is_primary": False})

    media = ListingMedia(
        listing_id=listing_id,
        file_url=result["file_url"],
        file_name=result["file_name"],
        original_name=result["original_name"],
        mime_type=result["mime_type"],
        file_size=result["file_size"],
        display_order=count,
        is_primary=is_primary or count == 0,  # first image is primary by default
    )
    db.add(media)
    db.commit()
    db.refresh(media)
    return media


@router.delete("/media/{media_id}")
def delete_listing_media(
    media_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    media = db.query(ListingMedia).filter(ListingMedia.id == media_id).first()
    if not media:
        raise HTTPException(status_code=404, detail="Media not found")

    listing = db.query(Listing).filter(Listing.id == media.listing_id).first()
    if listing.owner_id != current_user.id and current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Not your listing")

    delete_upload_file(media.file_url)
    db.delete(media)
    db.commit()
    return {"message": "Media deleted"}
