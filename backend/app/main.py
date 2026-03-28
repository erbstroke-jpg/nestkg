from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from starlette.middleware.sessions import SessionMiddleware
from app.routers.admin_panel import router as admin_panel_router

from app.config import settings
from app.database import engine, Base
from app.routers import auth, users, categories, listings, favorites, messaging, notifications, reports, payments, admin

# Create upload directories
Path(settings.UPLOAD_DIR).mkdir(parents=True, exist_ok=True)
for sub in ("avatars", "listings", "attachments"):
    (Path(settings.UPLOAD_DIR) / sub).mkdir(parents=True, exist_ok=True)

app = FastAPI(
    title="NestKG Real Estate API",
    description="Full-stack real estate marketplace platform API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS FIRST (добавляется первым, значит будет внутренним)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Session SECOND (добавляется вторым, значит будет внешним)
app.add_middleware(SessionMiddleware, secret_key=settings.JWT_SECRET_KEY)

# Static files for uploads
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# Register routers
app.include_router(admin_panel_router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(categories.router)
app.include_router(listings.router)
app.include_router(favorites.router)
app.include_router(messaging.router)
app.include_router(notifications.router)
app.include_router(reports.router)
app.include_router(payments.router)
app.include_router(admin.router)


@app.get("/", tags=["Health"])
def health_check():
    return {"status": "ok", "service": "NestKG Real Estate API"}


@app.get("/health", tags=["Health"])
def health():
    return {"status": "healthy"}


# Create tables on startup (use Alembic in production)
@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.APP_HOST, port=settings.APP_PORT, reload=settings.DEBUG)
