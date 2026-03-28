from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.listing import Listing, ListingStatus
from app.schemas.user import UserOut, UserPublicOut, UserUpdateRequest
from app.schemas.listing import ListingOut
from app.dependencies.auth import get_current_user
from app.dependencies.pagination import get_pagination, PaginationParams, paginated_response
from app.utils.files import save_upload_file
from app.config import settings

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserOut)
def get_my_profile(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me", response_model=UserOut)
def update_my_profile(
    req: UserUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    update_data = req.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.put("/me/avatar", response_model=UserOut)
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = await save_upload_file(
        file, "avatars", settings.allowed_image_types_list
    )
    current_user.profile_image_url = result["file_url"]
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/{user_id}/public", response_model=UserPublicOut)
def get_public_profile(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    count = db.query(Listing).filter(
        Listing.owner_id == user_id,
        Listing.status == ListingStatus.approved,
    ).count()

    return UserPublicOut(
        id=user.id,
        full_name=user.full_name,
        profile_image_url=user.profile_image_url,
        bio=user.bio,
        city=user.city,
        created_at=user.created_at,
        active_listings_count=count,
    )


@router.get("/{user_id}/listings")
def get_user_listings(
    user_id: int,
    pagination: PaginationParams = Depends(get_pagination),
    db: Session = Depends(get_db),
):
    query = db.query(Listing).filter(
        Listing.owner_id == user_id,
        Listing.status == ListingStatus.approved,
    ).order_by(Listing.created_at.desc())

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    return paginated_response(
        [ListingOut.model_validate(i) for i in items],
        total,
        pagination,
    )
