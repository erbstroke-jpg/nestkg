from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.models.user import User
from app.models.listing import Listing, ListingStatus
from app.models.favorite import Favorite
from app.schemas.listing import ListingOut
from app.dependencies.auth import get_current_user
from app.dependencies.pagination import get_pagination, PaginationParams, paginated_response

router = APIRouter(prefix="/favorites", tags=["Favorites"])


@router.post("/{listing_id}", status_code=status.HTTP_201_CREATED)
def add_favorite(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    existing = db.query(Favorite).filter(
        Favorite.user_id == current_user.id, Favorite.listing_id == listing_id
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Already in favorites")

    fav = Favorite(user_id=current_user.id, listing_id=listing_id)
    db.add(fav)
    db.commit()
    return {"message": "Added to favorites"}


@router.delete("/{listing_id}")
def remove_favorite(
    listing_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    fav = db.query(Favorite).filter(
        Favorite.user_id == current_user.id, Favorite.listing_id == listing_id
    ).first()
    if not fav:
        raise HTTPException(status_code=404, detail="Not in favorites")

    db.delete(fav)
    db.commit()
    return {"message": "Removed from favorites"}


@router.get("")
def list_favorites(
    pagination: PaginationParams = Depends(get_pagination),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = (
        db.query(Favorite)
        .options(joinedload(Favorite.listing).joinedload(Listing.owner))
        .options(joinedload(Favorite.listing).joinedload(Listing.category))
        .options(joinedload(Favorite.listing).joinedload(Listing.media))
        .filter(Favorite.user_id == current_user.id)
        .order_by(Favorite.created_at.desc())
    )

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    listings = []
    for fav in items:
        if fav.listing and fav.listing.status == ListingStatus.approved:
            out = ListingOut.model_validate(fav.listing)
            out.is_favorited = True
            listings.append(out)

    return paginated_response(listings, total, pagination)
