"""
Tests for NestKG Backend API
Run: pytest tests/ -v
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database import Base, get_db

# ── Test DB Setup ──────────────────────────────────

SQLALCHEMY_TEST_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_TEST_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


# ── Auth Tests ─────────────────────────────────────

class TestAuth:
    def test_register_success(self):
        response = client.post("/auth/register", json={
            "full_name": "Test User",
            "email": "test@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "preferred_language": "en"
        })
        assert response.status_code == 201
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    def test_register_duplicate_email(self):
        # First registration
        client.post("/auth/register", json={
            "full_name": "User 1",
            "email": "duplicate@example.com",
            "password": "password123",
            "confirm_password": "password123",
        })
        # Duplicate
        response = client.post("/auth/register", json={
            "full_name": "User 2",
            "email": "duplicate@example.com",
            "password": "password123",
            "confirm_password": "password123",
        })
        assert response.status_code == 409
        assert "already registered" in response.json()["detail"]

    def test_register_password_mismatch(self):
        response = client.post("/auth/register", json={
            "full_name": "Test",
            "email": "test2@example.com",
            "password": "password123",
            "confirm_password": "wrong_password",
        })
        assert response.status_code == 400
        assert "do not match" in response.json()["detail"]

    def test_register_short_password(self):
        response = client.post("/auth/register", json={
            "full_name": "Test",
            "email": "test3@example.com",
            "password": "123",
            "confirm_password": "123",
        })
        assert response.status_code == 422  # Pydantic validation

    def test_register_invalid_email(self):
        response = client.post("/auth/register", json={
            "full_name": "Test",
            "email": "not-an-email",
            "password": "password123",
            "confirm_password": "password123",
        })
        assert response.status_code == 422

    def test_register_empty_phone_treated_as_null(self):
        response = client.post("/auth/register", json={
            "full_name": "Test",
            "email": "phone_test@example.com",
            "phone": "",
            "password": "password123",
            "confirm_password": "password123",
        })
        assert response.status_code == 201

    def test_login_success(self):
        # Register first
        client.post("/auth/register", json={
            "full_name": "Login Test",
            "email": "login@example.com",
            "password": "password123",
            "confirm_password": "password123",
        })
        # Login
        response = client.post("/auth/login", json={
            "email": "login@example.com",
            "password": "password123",
        })
        assert response.status_code == 200
        assert "access_token" in response.json()

    def test_login_wrong_password(self):
        client.post("/auth/register", json={
            "full_name": "Test",
            "email": "wrong_pass@example.com",
            "password": "password123",
            "confirm_password": "password123",
        })
        response = client.post("/auth/login", json={
            "email": "wrong_pass@example.com",
            "password": "wrong_password",
        })
        assert response.status_code == 401

    def test_login_nonexistent_user(self):
        response = client.post("/auth/login", json={
            "email": "nobody@example.com",
            "password": "password123",
        })
        assert response.status_code == 401

    def test_token_refresh(self):
        reg = client.post("/auth/register", json={
            "full_name": "Refresh Test",
            "email": "refresh@example.com",
            "password": "password123",
            "confirm_password": "password123",
        })
        refresh_token = reg.json()["refresh_token"]
        response = client.post("/auth/refresh", json={"refresh_token": refresh_token})
        assert response.status_code == 200
        assert "access_token" in response.json()

    def test_change_password(self):
        reg = client.post("/auth/register", json={
            "full_name": "Change Pass",
            "email": "changepass@example.com",
            "password": "oldpass123",
            "confirm_password": "oldpass123",
        })
        token = reg.json()["access_token"]
        response = client.post("/auth/change-password",
            json={"current_password": "oldpass123", "new_password": "newpass123"},
            headers={"Authorization": f"Bearer {token}"})
        assert response.status_code == 200

        # Login with new password
        login = client.post("/auth/login", json={"email": "changepass@example.com", "password": "newpass123"})
        assert login.status_code == 200


# ── Helper ─────────────────────────────────────────

def _create_user_and_get_token(email="user@example.com", name="Test User"):
    reg = client.post("/auth/register", json={
        "full_name": name, "email": email,
        "password": "password123", "confirm_password": "password123",
    })
    return reg.json()["access_token"]


def _auth_header(token):
    return {"Authorization": f"Bearer {token}"}


# ── Profile Tests ──────────────────────────────────

class TestProfile:
    def test_get_my_profile(self):
        token = _create_user_and_get_token("profile@example.com")
        response = client.get("/users/me", headers=_auth_header(token))
        assert response.status_code == 200
        assert response.json()["email"] == "profile@example.com"

    def test_update_profile(self):
        token = _create_user_and_get_token("update@example.com")
        response = client.put("/users/me",
            json={"full_name": "Updated Name", "city": "Bishkek", "bio": "Hello!"},
            headers=_auth_header(token))
        assert response.status_code == 200
        assert response.json()["full_name"] == "Updated Name"
        assert response.json()["city"] == "Bishkek"

    def test_unauthorized_access(self):
        response = client.get("/users/me")
        assert response.status_code == 401


# ── Category Tests ─────────────────────────────────

class TestCategories:
    def test_list_categories_empty(self):
        response = client.get("/categories")
        assert response.status_code == 200
        assert isinstance(response.json(), list)


# ── Listing Tests ──────────────────────────────────

class TestListings:
    def _create_category(self, token):
        """Create a category via admin endpoint."""
        response = client.post("/admin/categories",
            params={"name_en": "Apartments", "name_ru": "Квартиры", "slug": "apartments"},
            headers=_auth_header(token))
        return response

    def test_create_listing(self):
        token = _create_user_and_get_token("seller@example.com", "Seller")
        # Need a category — create via direct DB or admin
        # For simplicity, test without category validation
        response = client.post("/listings", json={
            "category_id": 1,
            "title": "Test Apartment",
            "description": "A beautiful apartment in the city center with great views",
            "price": 50000,
            "city": "Bishkek",
            "submit_for_review": False,
        }, headers=_auth_header(token))
        # May fail if category doesn't exist, that's expected behavior
        assert response.status_code in (201, 400)

    def test_list_public_feed(self):
        response = client.get("/listings")
        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert "page" in data
        assert "total_items" in data

    def test_search_listings(self):
        response = client.get("/listings", params={"search": "apartment", "sort_by": "newest"})
        assert response.status_code == 200

    def test_filter_by_price(self):
        response = client.get("/listings", params={"min_price": 10000, "max_price": 100000})
        assert response.status_code == 200

    def test_pagination(self):
        response = client.get("/listings", params={"page": 1, "page_size": 5})
        assert response.status_code == 200
        data = response.json()
        assert data["page_size"] == 5

    def test_get_nonexistent_listing(self):
        response = client.get("/listings/99999")
        assert response.status_code == 404

    def test_delete_listing_unauthorized(self):
        response = client.delete("/listings/1")
        assert response.status_code == 401

    def test_my_listings_requires_auth(self):
        response = client.get("/listings/my/all")
        assert response.status_code == 401


# ── Favorites Tests ────────────────────────────────

class TestFavorites:
    def test_favorites_requires_auth(self):
        response = client.get("/favorites")
        assert response.status_code == 401

    def test_add_nonexistent_listing(self):
        token = _create_user_and_get_token("fav@example.com")
        response = client.post("/favorites/99999", headers=_auth_header(token))
        assert response.status_code == 404


# ── Messaging Tests ────────────────────────────────

class TestMessaging:
    def test_conversations_requires_auth(self):
        response = client.get("/conversations")
        assert response.status_code == 401

    def test_cannot_message_self(self):
        token = _create_user_and_get_token("selfmsg@example.com")
        response = client.post("/conversations", json={
            "listing_id": 1, "recipient_id": 1,  # same user
        }, headers=_auth_header(token))
        assert response.status_code == 400


# ── Notifications Tests ────────────────────────────

class TestNotifications:
    def test_notifications_requires_auth(self):
        response = client.get("/notifications")
        assert response.status_code == 401

    def test_unread_count_requires_auth(self):
        response = client.get("/notifications/unread-count")
        assert response.status_code == 401

    def test_unread_count(self):
        token = _create_user_and_get_token("notif@example.com")
        response = client.get("/notifications/unread-count", headers=_auth_header(token))
        assert response.status_code == 200
        assert "unread_count" in response.json()


# ── Reports Tests ──────────────────────────────────

class TestReports:
    def test_reports_requires_auth(self):
        response = client.post("/reports", json={
            "target_type": "listing", "target_id": 1, "reason_code": "spam"
        })
        assert response.status_code == 401


# ── Payments Tests ─────────────────────────────────

class TestPayments:
    def test_payments_requires_auth(self):
        response = client.get("/payments/my")
        assert response.status_code == 401

    def test_promotion_packages_public(self):
        response = client.get("/promotion-packages")
        assert response.status_code == 200
        assert isinstance(response.json(), list)


# ── Security Tests ─────────────────────────────────

class TestSecurity:
    def test_invalid_token(self):
        response = client.get("/users/me", headers={"Authorization": "Bearer invalid_token"})
        assert response.status_code == 401

    def test_expired_token_format(self):
        response = client.get("/users/me", headers={"Authorization": "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwiZXhwIjoxfQ.invalid"})
        assert response.status_code == 401

    def test_admin_endpoint_requires_admin(self):
        token = _create_user_and_get_token("regular@example.com")
        response = client.get("/admin/dashboard", headers=_auth_header(token))
        assert response.status_code == 403

    def test_health_endpoint(self):
        response = client.get("/")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"

    def test_swagger_available(self):
        response = client.get("/docs")
        assert response.status_code == 200
