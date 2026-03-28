from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models.user import User
from app.schemas.auth import TokenPair, UserCreate
from app.utils.security import create_token, hash_password, verify_password


class AuthService:
    @staticmethod
    def register(db: Session, payload: UserCreate) -> User:
        by_email = db.scalar(select(User).where(User.email == payload.email))
        if by_email:
            raise ValueError("User with provided email already exists.")

        if payload.phone:
            by_phone = db.scalar(select(User).where(User.phone == payload.phone))
            if by_phone:
                raise ValueError("User with provided phone already exists.")

        user = User(
            full_name=payload.full_name,
            email=payload.email,
            phone=payload.phone,
            password_hash=hash_password(payload.password),
            role=payload.role,
            status=payload.status,
            profile_image_url=payload.profile_image_url,
            bio=payload.bio,
            city=payload.city,
            preferred_language=payload.preferred_language,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    @staticmethod
    def login(db: Session, email: str, password: str) -> User:
        user = db.scalar(select(User).where(User.email == email))
        if not user or not verify_password(password, user.password_hash):
            raise ValueError("Invalid email or password.")
        return user

    @staticmethod
    def create_token_pair(user_id: int) -> TokenPair:
        subject = str(user_id)
        access = create_token(
            subject=subject,
            token_type="access",
            expires_minutes=settings.jwt_access_token_exp_minutes,
        )
        refresh = create_token(
            subject=subject,
            token_type="refresh",
            expires_minutes=settings.jwt_refresh_token_exp_minutes,
        )
        return TokenPair(access_token=access, refresh_token=refresh)
