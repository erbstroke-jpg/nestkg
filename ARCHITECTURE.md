# Marketplace Platform — Architecture & System Design

## 1. Domain: Car Marketplace (AutoBazar)

Chosen theme: **Car Marketplace** — rich category attributes (brand, model, year, mileage, fuel type), clear pricing model, natural fit for promotions/boosting.

## 2. High-Level Architecture

```
┌──────────────┐       REST/JSON        ┌──────────────────┐        ORM         ┌─────────┐
│  Flutter App  │ ◄───────────────────► │   FastAPI Backend  │ ◄───────────────► │  MySQL   │
│  (Dart/Riverpod)                      │   (Python 3.11+)   │                   │  8.0+    │
└──────────────┘                        ├──────────────────┤                   └─────────┘
                                        │  Jinja2 Admin UI  │
┌──────────────┐       REST/JSON        │  (Bootstrap 5)     │
│  Admin Panel  │ ◄───────────────────► └──────────────────┘
│  (Web Browser)│                              │
└──────────────┘                        ┌──────┴──────┐
                                        │ Local File   │
                                        │ Storage      │
                                        │ /uploads/    │
                                        └─────────────┘
```

## 3. Database Schema (ER)

### users
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| full_name | VARCHAR(100) | NOT NULL |
| email | VARCHAR(255) | UNIQUE, NOT NULL |
| phone | VARCHAR(20) | UNIQUE, nullable |
| password_hash | VARCHAR(255) | NOT NULL |
| role | ENUM(user,admin) | DEFAULT user |
| status | ENUM(active,blocked,pending_verification,deleted) | DEFAULT pending_verification |
| profile_image_url | VARCHAR(500) | nullable |
| bio | TEXT | nullable |
| city | VARCHAR(100) | nullable |
| preferred_language | ENUM(en,ru) | DEFAULT en |
| blocked_until | DATETIME | nullable (for temp blocks) |
| created_at | DATETIME | DEFAULT NOW |
| updated_at | DATETIME | ON UPDATE NOW |
| last_seen_at | DATETIME | nullable |

### categories
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| parent_id | INT FK(categories.id) | nullable |
| name_en | VARCHAR(100) | NOT NULL |
| name_ru | VARCHAR(100) | NOT NULL |
| slug | VARCHAR(100) | UNIQUE |
| icon_url | VARCHAR(500) | nullable |
| is_active | BOOLEAN | DEFAULT true |
| display_order | INT | DEFAULT 0 |
| attributes_schema | JSON | dynamic fields definition |
| created_at | DATETIME | |

### listings
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| owner_id | INT FK(users.id) | NOT NULL |
| category_id | INT FK(categories.id) | NOT NULL |
| title | VARCHAR(200) | NOT NULL |
| description | TEXT | NOT NULL |
| price | DECIMAL(12,2) | NOT NULL, >= 0 |
| currency | VARCHAR(3) | DEFAULT 'USD' |
| city | VARCHAR(100) | NOT NULL |
| latitude | DECIMAL(10,7) | nullable |
| longitude | DECIMAL(10,7) | nullable |
| condition | ENUM(new,like_new,good,fair,parts) | nullable |
| is_negotiable | BOOLEAN | DEFAULT false |
| contact_preference | ENUM(chat,phone,both) | DEFAULT chat |
| status | ENUM(draft,pending_review,approved,rejected,archived,sold) | DEFAULT draft |
| moderation_note | TEXT | nullable |
| view_count | INT | DEFAULT 0 |
| attributes_json | JSON | category-specific fields |
| created_at | DATETIME | |
| updated_at | DATETIME | |
| published_at | DATETIME | nullable |
| expires_at | DATETIME | nullable |

### listing_media
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| listing_id | INT FK(listings.id) | NOT NULL |
| file_url | VARCHAR(500) | NOT NULL |
| file_name | VARCHAR(255) | UUID-generated |
| original_name | VARCHAR(255) | |
| mime_type | VARCHAR(50) | |
| file_size | INT | bytes |
| display_order | INT | DEFAULT 0 |
| is_primary | BOOLEAN | DEFAULT false |
| created_at | DATETIME | |

### favorites
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| user_id | INT FK(users.id) | NOT NULL |
| listing_id | INT FK(listings.id) | NOT NULL |
| created_at | DATETIME | |
| **UNIQUE** | (user_id, listing_id) | |

### conversations
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| listing_id | INT FK(listings.id) | nullable |
| participant_a_id | INT FK(users.id) | NOT NULL |
| participant_b_id | INT FK(users.id) | NOT NULL |
| last_message_at | DATETIME | nullable |
| created_at | DATETIME | |
| updated_at | DATETIME | |

**Constraint:** To avoid duplicate conversations, always store smaller user_id as participant_a_id. Check both directions on lookup.

### messages
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| conversation_id | INT FK(conversations.id) | NOT NULL |
| sender_id | INT FK(users.id) | NOT NULL |
| text_body | TEXT | nullable (can be attachment-only) |
| message_type | ENUM(text,attachment,mixed) | DEFAULT text |
| is_read | BOOLEAN | DEFAULT false |
| sent_at | DATETIME | DEFAULT NOW |
| deleted_at | DATETIME | nullable, soft delete |

### message_attachments
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| message_id | INT FK(messages.id) | NOT NULL |
| file_name | VARCHAR(255) | UUID-generated |
| original_name | VARCHAR(255) | |
| mime_type | VARCHAR(50) | |
| file_size | INT | |
| file_url | VARCHAR(500) | |
| created_at | DATETIME | |

### notifications
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| user_id | INT FK(users.id) | NOT NULL |
| type | ENUM(listing_approved,listing_rejected,new_message,report_status,payment_success,promo_activated,promo_expired) | |
| title | VARCHAR(200) | |
| body | TEXT | |
| reference_type | VARCHAR(50) | nullable (listing, conversation, etc.) |
| reference_id | INT | nullable |
| is_read | BOOLEAN | DEFAULT false |
| created_at | DATETIME | |

### reports
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| reporter_user_id | INT FK(users.id) | NOT NULL |
| target_type | ENUM(listing,user,message) | NOT NULL |
| target_id | INT | NOT NULL |
| reason_code | ENUM(spam,fake,scam,duplicate,offensive,prohibited,harassment,other) | |
| reason_text | TEXT | nullable |
| status | ENUM(pending,resolved,dismissed) | DEFAULT pending |
| resolution_note | TEXT | nullable |
| reviewed_by_admin_id | INT FK(users.id) | nullable |
| created_at | DATETIME | |
| reviewed_at | DATETIME | nullable |

### promotion_packages
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| name_en | VARCHAR(100) | |
| name_ru | VARCHAR(100) | |
| promotion_type | ENUM(featured,boosted,top_of_feed) | |
| duration_days | INT | |
| price | DECIMAL(10,2) | |
| currency | VARCHAR(3) | DEFAULT 'USD' |
| is_active | BOOLEAN | DEFAULT true |
| created_at | DATETIME | |

### promotions
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| listing_id | INT FK(listings.id) | NOT NULL |
| user_id | INT FK(users.id) | NOT NULL |
| package_id | INT FK(promotion_packages.id) | NOT NULL |
| promotion_type | ENUM(featured,boosted,top_of_feed) | |
| target_city | VARCHAR(100) | nullable |
| target_category_id | INT FK(categories.id) | nullable |
| starts_at | DATETIME | |
| ends_at | DATETIME | |
| status | ENUM(pending_payment,active,expired,cancelled) | DEFAULT pending_payment |
| purchased_price | DECIMAL(10,2) | |
| payment_id | INT FK(payments.id) | nullable |
| created_at | DATETIME | |

### payments
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| user_id | INT FK(users.id) | NOT NULL |
| listing_id | INT FK(listings.id) | nullable |
| promotion_id | INT FK(promotions.id) | nullable |
| amount | DECIMAL(10,2) | NOT NULL |
| currency | VARCHAR(3) | DEFAULT 'USD' |
| status | ENUM(pending,successful,failed,cancelled,refunded) | DEFAULT pending |
| payment_provider | VARCHAR(50) | e.g. 'mock', 'stripe' |
| provider_reference | VARCHAR(255) | nullable |
| created_at | DATETIME | |
| updated_at | DATETIME | |
| paid_at | DATETIME | nullable |

### admin_audit_logs
| Column | Type | Notes |
|--------|------|-------|
| id | INT PK AUTO | |
| admin_id | INT FK(users.id) | NOT NULL |
| action | VARCHAR(100) | e.g. 'approve_listing', 'block_user' |
| target_type | VARCHAR(50) | |
| target_id | INT | |
| details_json | JSON | nullable |
| ip_address | VARCHAR(45) | nullable |
| created_at | DATETIME | |

## 4. State Machines

### Listing Status
```
draft → pending_review → approved → sold
                       → approved → archived
                       → rejected → (edit) → pending_review
```

### Payment Status
```
pending → successful → refunded
        → failed
        → cancelled
```

### Promotion Status
```
pending_payment → active → expired
                → cancelled
```

### User Status
```
pending_verification → active → blocked → active
                               active → deleted
```

## 5. API Route Groups

```
POST   /auth/register
POST   /auth/login
POST   /auth/refresh
POST   /auth/forgot-password
POST   /auth/reset-password
POST   /auth/change-password

GET    /users/me
PUT    /users/me
PUT    /users/me/avatar
GET    /users/{id}/public
GET    /users/{id}/listings

GET    /categories
GET    /categories/{id}

POST   /listings
GET    /listings                    (public feed, filters, search, sort, pagination)
GET    /listings/{id}
PUT    /listings/{id}
DELETE /listings/{id}
GET    /listings/my

POST   /listings/{id}/media
DELETE /listing-media/{id}
PUT    /listing-media/{id}/order

POST   /favorites/{listing_id}
DELETE /favorites/{listing_id}
GET    /favorites

POST   /conversations
GET    /conversations
GET    /conversations/{id}
POST   /conversations/{id}/messages
GET    /conversations/{id}/messages

POST   /messages/{id}/attachments
GET    /attachments/{id}/download

GET    /notifications
PUT    /notifications/{id}/read
PUT    /notifications/read-all

POST   /reports
GET    /reports/my

POST   /payments/initiate
POST   /payments/{id}/confirm       (mock callback)
GET    /payments/my

GET    /promotion-packages
POST   /promotions/purchase
GET    /promotions/my

# Admin routes
GET    /admin/dashboard
GET/PUT /admin/users
GET/PUT /admin/listings
GET/PUT /admin/reports
GET/PUT /admin/categories
GET/PUT /admin/payments
GET/PUT /admin/promotions
GET/PUT /admin/promotion-packages
GET    /admin/audit-logs
GET    /admin/conversations/{id}    (for abuse investigation)
```

## 6. Key Architecture Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| State management (Flutter) | Riverpod | Modern, testable, good for DI |
| ORM | SQLAlchemy 2.0 | Industry standard, good async support |
| Migrations | Alembic | Pairs with SQLAlchemy |
| Admin panel | Jinja2 + Bootstrap 5 | Fastest to build, no separate deploy |
| File storage | Local /uploads/ | Simple for dev, abstracted for future S3 |
| File naming | UUID v4 | Security — no original filenames exposed |
| Soft delete | deleted_at column | Preserve data integrity |
| Chat dedup | Normalized participant order | Smaller ID always = participant_a |
| Category attributes | JSON column | Flexible, no schema changes per category |
| Localization (DB) | name_en, name_ru columns | Simple, no join overhead |
| Localization (Flutter) | ARB files | Standard Flutter l10n |
| Promoted in feed | Two-phase query | Promoted first block, then regular |
| Password hashing | bcrypt via passlib | Industry standard |
| JWT | access (30min) + refresh (7d) | Secure session management |
| Map | flutter_map + OSM | Free, no API key needed |

## 7. Security Checklist

- [x] bcrypt password hashing
- [x] JWT with expiration
- [x] Server-side ownership checks on all mutations
- [x] Admin role check middleware
- [x] File type + size validation
- [x] UUID filenames (no path traversal)
- [x] CORS configuration
- [x] Environment variables for secrets
- [x] No secrets in git (.env.example only)
- [x] Rate limiting on auth endpoints
- [x] Input validation via Pydantic
- [x] SQL injection prevention via ORM
