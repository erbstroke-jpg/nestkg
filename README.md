# NestKG — Real Estate Marketplace Platform

> Full-stack real estate marketplace: Flutter mobile app + FastAPI backend + MySQL + Admin panel

<p align="center">
  <b>🏠 NestKG — Найди свой дом</b><br>
  <i>Маркетплейс недвижимости Кыргызстана</i>
</p>

---

## 📋 Project Overview

NestKG is a production-grade real estate marketplace. Users can list apartments, houses, land, and commercial properties. The platform supports messaging with attachments, promotion/boosting system with mock payments, multi-language support (EN/RU), and a comprehensive admin panel.

**Domain:** Real Estate (Apartments, Houses, Commercial, Land, Rentals)

## 🏗 Architecture

```
┌──────────────────┐     REST/JSON      ┌──────────────────┐       ORM        ┌─────────┐
│  Flutter App      │ ◄────────────────► │  FastAPI Backend  │ ◄──────────────► │  MySQL   │
│  (Riverpod + Dio) │                    │  (Python 3.11)    │                  │  8.0     │
└──────────────────┘                    ├──────────────────┤                  └─────────┘
                                        │  Admin Panel      │
┌──────────────────┐     Jinja2/HTML    │  (Bootstrap 5)    │
│  Web Browser      │ ◄────────────────► └──────────────────┘
└──────────────────┘                           │
                                        ┌──────┴──────┐
                                        │ File Storage │
                                        │ /uploads/    │
                                        └─────────────┘
```

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.41, Dart, Riverpod, Dio, flutter_map (OSM) |
| Backend | Python 3.11, FastAPI, SQLAlchemy 2.0, Pydantic v2 |
| Database | MySQL 8.0, 15 normalized tables |
| Admin | Jinja2 templates, Bootstrap 5, Bootstrap Icons |
| Auth | JWT (access + refresh tokens), bcrypt hashing |
| Deploy | Docker Compose |
| Localization | Flutter ARB (EN/RU), backend bilingual fields |

---

## 🚀 Quick Start (Docker Compose — рекомендуется)

### Требования
- Docker Desktop (https://www.docker.com/products/docker-desktop)
- Flutter SDK 3.3+ (https://docs.flutter.dev/get-started/install)

### 1. Запуск бэкенда + БД

```bash
# Из корня проекта:
docker-compose up --build
```

> ⏳ Первый запуск: ~2-3 минуты (скачивание образов, сборка, seed данных)

Дождитесь в логах:
```
DATABASE SEEDED SUCCESSFULLY — NestKG
```

Проверьте:
- API: http://localhost:8000
- Swagger: http://localhost:8000/docs
- Admin: http://localhost:8000/admin/login

### 2. Запуск Flutter приложения

```bash
cd flutter_app
flutter pub get
flutter gen-l10n
flutter run -d chrome --dart-define=BASE_URL=http://localhost:8000
```

> Для Android эмулятора: `--dart-define=BASE_URL=http://10.0.2.2:8000`

### 3. Готовый APK

APK файл находится в корне проекта: `app-release.apk`

---

## ⚠️ Troubleshooting (Частые проблемы)

### Порт 3306 занят (локальный MySQL)

```
Error: Bind for 0.0.0.0:3306 failed: port is already allocated
```

**Решение:** Остановите локальный MySQL или измените порт в `docker-compose.yml`:
```yaml
ports:
  - "3307:3306"  # внешний порт 3307, внутренний 3306
```
Бэкенд внутри Docker подключается к `db:3306` (внутренний), поэтому `DB_PORT` менять не нужно.

### Docker контейнер уже существует

```
Error: container name already in use
```

**Решение:**
```bash
docker rm -f $(docker ps -aq)
docker-compose up --build
```

### bcrypt ошибка (passlib)

```
AttributeError: module 'bcrypt' has no attribute '__about__'
```

**Решение:** В `requirements.txt` должны быть зафиксированные версии:
```
passlib==1.7.4
bcrypt==4.0.1
```

### Flutter gen-l10n ошибка

```
The 'arb-dir' directory does not exist
```

**Решение:** Убедитесь что существует `flutter_app/lib/l10n/app_en.arb` и `app_ru.arb`.

### CORS ошибка (Flutter Web)

```
Access-Control-Allow-Origin header is not present
```

**Решение:** В `backend/app/main.py` middleware должны быть в правильном порядке:
```python
# CORS первым (будет обрабатывать запросы последним — внешний)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=False,
                   allow_methods=["*"], allow_headers=["*"])
# Session вторым
app.add_middleware(SessionMiddleware, secret_key=settings.JWT_SECRET_KEY)
```

### Flutter APK — JAVA_HOME

```
Error: Could not find or load main class org.gradle.wrapper.GradleWrapperMain
```

**Решение:** Установите Android Studio, затем:
```powershell
# PowerShell (Windows):
$env:JAVA_HOME = "C:\Program Files\Android\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
flutter build apk --release --dart-define=BASE_URL=http://YOUR_IP:8000
```

---

## 🔑 Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| **Admin** | admin@nestkg.com | admin123 |
| Realtor | azamat@example.com | user123 |
| Seller | aigul@example.com | user123 |
| Buyer | buyer@example.com | user123 |

---

## 📱 Demo Video

🎬 **[Ссылка на демо-видео](https://drive.google.com/file/d/1st-Lni6_B4DOLWlmkKtzDqxlYMAemLIP/view?usp=sharing)**

Длительность: ~6 минут. Показан весь функционал платформы(Через Flutter Web, сам APK файл в корневой папке проекта).

---

## 🗄 Database Design (15 tables)

```
users ──┬── listings ──── listing_media
        ├── favorites
        ├── conversations ── messages ── message_attachments
        ├── notifications
        ├── reports
        ├── payments
        └── promotions ──── promotion_packages
categories ──┘
admin_audit_logs
```

### Key Design Decisions

| Решение | Выбор | Обоснование |
|---------|-------|-------------|
| Soft delete | Статусы (archived/deleted) | Сохранение целостности данных, аудит |
| Category attributes | JSON schema + JSON values | Гибкость — новые категории без миграций |
| Conversation dedup | Нормализация participant order | min(a,b) = participant_a, предотвращает дубликаты |
| Localization (DB) | `name_en`/`name_ru` колонки | Простота, нет overhead от JOIN |
| Listing status | State machine | draft→pending→approved→sold; rejected→edit→pending |
| File naming | UUID v4 | Безопасность — нет path traversal |
| Promoted feed | Двухфазный запрос | Promoted первыми, затем обычные |

---

## 🛡 Security

- ✅ bcrypt password hashing (passlib + bcrypt)
- ✅ JWT access (30min) + refresh (7 days) tokens
- ✅ Server-side ownership checks on all mutations
- ✅ Admin role verification middleware
- ✅ File type + size validation (max 10MB)
- ✅ UUID filenames (no original names exposed)
- ✅ CORS configuration
- ✅ Environment variables for secrets (.env)
- ✅ SQL injection prevention via ORM
- ✅ Input validation via Pydantic schemas

---

## 💳 Payment / Promotion Model

Payments are **mocked** (no real gateway), but architecture is production-oriented:

```
User selects promo package
    → Chooses target (city/category)
    → Payment record created (status: pending)
    → Mock confirm endpoint called
    → Payment status → successful
    → Promotion activated (start/end dates set)
    → Listing appears prioritized in feed
```

Promotion types: **Featured**, **Boosted**, **Top of Feed**
Targeting: city-based, category-based, time-based duration

---

## 🌐 Localization

**Flutter (120+ keys):** EN/RU via ARB files
- All navigation, buttons, forms, validation messages, statuses
- Language switchable in Profile → Settings
- Persisted via SharedPreferences

**Backend:**
- Categories: `name_en` / `name_ru`
- Promotion packages: `name_en` / `name_ru`
- User preferred language stored in profile
- API returns machine-readable enum codes

---

## 📊 Admin Panel (http://localhost:8000/admin)

| Section | Features |
|---------|----------|
| Dashboard | 13 real-time counters (users, listings, revenue, etc.) |
| Users | Search, detail view, suspend/unsuspend (7 days) |
| Listings | Filter by status/category/city, approve/reject/archive |
| Reports | Filter by status/reason, resolve/dismiss with notes |
| Categories | CRUD, toggle active, bilingual names |
| Promotions | Packages CRUD, active/expired list, deactivate |
| Payments | Filter by status, transaction history |
| Conversations | Inspect for abuse (linked to reports) |
| Audit Log | All admin actions with timestamps |

---

## 📁 API Endpoints

Interactive docs: **http://localhost:8000/docs**

| Group | Endpoints |
|-------|-----------|
| `/auth` | register, login, refresh, change-password, forgot/reset |
| `/users` | profile CRUD, avatar upload, public profile |
| `/categories` | list, detail |
| `/listings` | CRUD, search/filter/sort, pagination, media upload |
| `/favorites` | add, remove, list |
| `/conversations` | create, list |
| `/conversations/{id}/messages` | send, list, attachments |
| `/notifications` | list, unread count, mark read |
| `/reports` | create |
| `/payments` | initiate, confirm (mock), history |
| `/promotions` | purchase, list packages |
| `/admin/*` | dashboard, moderation, management |

---

## ⚡ Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| DB_HOST | db | MySQL host (Docker service name) |
| DB_PORT | 3306 | MySQL port |
| DB_NAME | marketplace | Database name |
| DB_USER | root | MySQL user |
| DB_PASSWORD | — | MySQL password |
| JWT_SECRET_KEY | — | JWT signing secret |
| ACCESS_TOKEN_EXPIRE_MINUTES | 30 | Access token TTL |
| REFRESH_TOKEN_EXPIRE_DAYS | 7 | Refresh token TTL |
| UPLOAD_DIR | uploads | File upload directory |
| MAX_FILE_SIZE_MB | 10 | Max upload size |

---

## 🚧 Known Limitations

- No real-time messaging (polling-based, not WebSocket)
- No push notifications (database-backed only)
- Payment gateway is mocked
- No email verification (mocked flow)
- Images not compressed server-side
- Single-server file storage (no S3)

## 🔮 Future Work

- WebSocket for real-time chat
- Image compression pipeline
- Stripe/Mbank payment integration
- Email/SMS OTP verification
- Push notifications (FCM)
- Advanced admin analytics with charts
- Wallet/balance system
- Cloud deployment (AWS/GCP)
