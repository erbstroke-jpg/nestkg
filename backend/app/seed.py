"""
Seed script: creates demo data for NestKG — real estate marketplace.
Run: python -m app.seed
"""
from datetime import datetime, timedelta, timezone

from app.database import SessionLocal, engine, Base
from app.models.user import User, UserRole, UserStatus, LanguageCode
from app.models.category import Category
from app.models.listing import Listing, ListingStatus, ListingCondition, ContactPreference
from app.models.promotion_package import PromotionPackage, PromotionType
from app.utils.security import hash_password


def seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        if db.query(User).first():
            print("Database already seeded. Skipping.")
            return

        # ── Users ────────────────────────────────────
        admin = User(
            full_name="Admin NestKG",
            email="admin@nestkg.com",
            password_hash=hash_password("admin123"),
            role=UserRole.admin,
            status=UserStatus.active,
            city="Бишкек",
            preferred_language=LanguageCode.ru,
        )
        user1 = User(
            full_name="Азамат Риелтор",
            email="azamat@example.com",
            password_hash=hash_password("user123"),
            role=UserRole.user,
            status=UserStatus.active,
            city="Бишкек",
            bio="Профессиональный риелтор. Помогаю найти лучшее жильё в Бишкеке.",
            preferred_language=LanguageCode.ru,
        )
        user2 = User(
            full_name="Айгуль Продавец",
            email="aigul@example.com",
            password_hash=hash_password("user123"),
            role=UserRole.user,
            status=UserStatus.active,
            city="Ош",
            bio="Продаю недвижимость в Оше и окрестностях",
            preferred_language=LanguageCode.ru,
        )
        user3 = User(
            full_name="Demo Buyer",
            email="buyer@example.com",
            password_hash=hash_password("user123"),
            role=UserRole.user,
            status=UserStatus.active,
            city="Каракол",
            preferred_language=LanguageCode.en,
        )
        db.add_all([admin, user1, user2, user3])
        db.commit()

        # ── Categories ───────────────────────────────
        categories_data = [
            {
                "name_en": "Apartments", "name_ru": "Квартиры", "slug": "apartments",
                "display_order": 1,
                "attributes_schema": {
                    "rooms": {"type": "integer", "required": True, "label_en": "Rooms", "label_ru": "Комнат"},
                    "area_sqm": {"type": "float", "required": True, "label_en": "Area (m²)", "label_ru": "Площадь (м²)"},
                    "floor": {"type": "integer", "label_en": "Floor", "label_ru": "Этаж"},
                    "total_floors": {"type": "integer", "label_en": "Total floors", "label_ru": "Всего этажей"},
                    "building_type": {"type": "enum", "options": ["brick", "panel", "monolith", "block"],
                                      "label_en": "Building type", "label_ru": "Тип дома"},
                    "renovation": {"type": "enum", "options": ["euro", "cosmetic", "designer", "needs_repair"],
                                   "label_en": "Renovation", "label_ru": "Ремонт"},
                    "furnishing": {"type": "enum", "options": ["furnished", "semi", "unfurnished"],
                                   "label_en": "Furnishing", "label_ru": "Мебель"},
                },
            },
            {
                "name_en": "Houses", "name_ru": "Дома", "slug": "houses",
                "display_order": 2,
                "attributes_schema": {
                    "rooms": {"type": "integer", "required": True},
                    "area_sqm": {"type": "float", "required": True},
                    "land_sqm": {"type": "float", "label_en": "Land area (m²)", "label_ru": "Участок (сотки)"},
                    "floors": {"type": "integer", "label_en": "Floors", "label_ru": "Этажей"},
                    "building_type": {"type": "enum", "options": ["brick", "adobe", "frame", "concrete"]},
                    "heating": {"type": "enum", "options": ["central", "gas", "electric", "solid_fuel"]},
                    "garage": {"type": "boolean", "label_en": "Garage", "label_ru": "Гараж"},
                },
            },
            {
                "name_en": "Commercial", "name_ru": "Коммерческая", "slug": "commercial",
                "display_order": 3,
                "attributes_schema": {
                    "area_sqm": {"type": "float", "required": True},
                    "property_type": {"type": "enum", "options": ["office", "retail", "warehouse", "restaurant", "hotel"]},
                    "parking_spaces": {"type": "integer"},
                },
            },
            {
                "name_en": "Land", "name_ru": "Земля", "slug": "land",
                "display_order": 4,
                "attributes_schema": {
                    "land_sqm": {"type": "float", "required": True},
                    "land_type": {"type": "enum", "options": ["residential", "agricultural", "industrial", "commercial"]},
                    "utilities": {"type": "enum", "options": ["all", "electricity_only", "none"]},
                },
            },
            {
                "name_en": "Rentals", "name_ru": "Аренда", "slug": "rentals",
                "display_order": 5,
                "attributes_schema": {
                    "rooms": {"type": "integer"},
                    "area_sqm": {"type": "float"},
                    "rental_period": {"type": "enum", "options": ["daily", "monthly", "long_term"]},
                    "furnishing": {"type": "enum", "options": ["furnished", "semi", "unfurnished"]},
                    "utilities_included": {"type": "boolean"},
                },
            },
        ]

        cats = []
        for cd in categories_data:
            cat = Category(**cd)
            db.add(cat)
            cats.append(cat)
        db.commit()

        # ── Listings ─────────────────────────────────
        now = datetime.now(timezone.utc)
        listings_data = [
            {
                "owner_id": user1.id, "category_id": cats[0].id,
                "title": "3-комн. квартира в центре Бишкека, 105 м²",
                "description": "Просторная 3-комнатная квартира в элитном доме на пересечении Боконбаева/Панфилова. Евроремонт, итальянская мебель, тёплый пол. Закрытый двор, подземный паркинг. Вид на горы.",
                "price": 95000, "currency": "USD", "city": "Бишкек",
                "latitude": 42.8746, "longitude": 74.5698,
                "condition": ListingCondition.renovated, "is_negotiable": True,
                "status": ListingStatus.approved, "published_at": now - timedelta(days=5),
                "view_count": 342,
                "attributes_json": {"rooms": 3, "area_sqm": 105, "floor": 7, "total_floors": 12,
                                    "building_type": "monolith", "renovation": "euro", "furnishing": "furnished"},
            },
            {
                "owner_id": user1.id, "category_id": cats[0].id,
                "title": "1-комн. квартира в мкр. Джал, 45 м²",
                "description": "Уютная однушка с ремонтом. Встроенная кухня, кондиционер, стиральная машина. Рядом школа, садик, супермаркет. Тихий район.",
                "price": 38000, "currency": "USD", "city": "Бишкек",
                "latitude": 42.8500, "longitude": 74.6100,
                "condition": ListingCondition.secondary, "is_negotiable": True,
                "status": ListingStatus.approved, "published_at": now - timedelta(days=3),
                "view_count": 187,
                "attributes_json": {"rooms": 1, "area_sqm": 45, "floor": 3, "total_floors": 9,
                                    "building_type": "panel", "renovation": "cosmetic", "furnishing": "furnished"},
            },
            {
                "owner_id": user2.id, "category_id": cats[1].id,
                "title": "Дом с участком в Оше, 200 м² на 8 сотках",
                "description": "Кирпичный дом в хорошем состоянии. 5 комнат, 2 санузла, гараж на 2 машины. Фруктовый сад, виноградник. Центральное отопление. Документы готовы.",
                "price": 65000, "currency": "USD", "city": "Ош",
                "latitude": 40.5283, "longitude": 72.7985,
                "condition": ListingCondition.secondary, "is_negotiable": False,
                "status": ListingStatus.approved, "published_at": now - timedelta(days=7),
                "view_count": 256,
                "attributes_json": {"rooms": 5, "area_sqm": 200, "land_sqm": 800,
                                    "floors": 2, "building_type": "brick", "heating": "central", "garage": True},
            },
            {
                "owner_id": user1.id, "category_id": cats[0].id,
                "title": "2-комн. квартира в 7 мкр, 62 м²",
                "description": "Хороший вариант для семьи. Средний этаж, не угловая. Косметический ремонт, пластиковые окна. Рядом остановка, рынок Дордой.",
                "price": 42000, "currency": "USD", "city": "Бишкек",
                "condition": ListingCondition.secondary,
                "status": ListingStatus.approved, "published_at": now - timedelta(days=1),
                "view_count": 89,
                "attributes_json": {"rooms": 2, "area_sqm": 62, "floor": 5, "total_floors": 9,
                                    "building_type": "panel", "renovation": "cosmetic"},
            },
            {
                "owner_id": user2.id, "category_id": cats[3].id,
                "title": "Участок 10 соток в Чолпон-Ате",
                "description": "Ровный участок под строительство, 200 м от озера Иссык-Куль. Электричество подведено, вода — скважина. Красный книга.",
                "price": 15000, "currency": "USD", "city": "Чолпон-Ата",
                "latitude": 42.6500, "longitude": 77.0800,
                "condition": ListingCondition.new_building,
                "status": ListingStatus.approved, "published_at": now - timedelta(days=2),
                "view_count": 412,
                "attributes_json": {"land_sqm": 1000, "land_type": "residential", "utilities": "electricity_only"},
            },
            {
                "owner_id": user3.id, "category_id": cats[2].id,
                "title": "Офис 120 м² в БЦ Ала-Тоо, Бишкек",
                "description": "Современный офис с ремонтом. Open space + 3 кабинета + переговорная. Парковка 4 места. Охрана, ресепшн.",
                "price": 180000, "currency": "USD", "city": "Бишкек",
                "condition": ListingCondition.renovated, "is_negotiable": True,
                "status": ListingStatus.approved, "published_at": now - timedelta(days=4),
                "view_count": 78,
                "attributes_json": {"area_sqm": 120, "property_type": "office", "parking_spaces": 4},
            },
            {
                "owner_id": user3.id, "category_id": cats[4].id,
                "title": "Сдаю 2-комн. квартиру посуточно в центре",
                "description": "Чистая, уютная квартира для гостей города. Wi-Fi, кондиционер, полный набор посуды. Рядом площадь Ала-Тоо.",
                "price": 35, "currency": "USD", "city": "Бишкек",
                "condition": ListingCondition.renovated,
                "status": ListingStatus.approved, "published_at": now - timedelta(days=1),
                "view_count": 523,
                "attributes_json": {"rooms": 2, "area_sqm": 55, "rental_period": "daily",
                                    "furnishing": "furnished", "utilities_included": True},
            },
            {
                "owner_id": user1.id, "category_id": cats[0].id,
                "title": "Черновик: Пентхаус 150 м²",
                "description": "Ещё пишу описание...",
                "price": 200000, "currency": "USD", "city": "Бишкек",
                "status": ListingStatus.draft,
            },
            {
                "owner_id": user2.id, "category_id": cats[1].id,
                "title": "Новый дом в Кара-Балте — на модерации",
                "description": "Новостройка, сдача в этом году. 4 комнаты, 2 этажа, участок 6 соток.",
                "price": 55000, "currency": "USD", "city": "Кара-Балта",
                "status": ListingStatus.pending_review, "published_at": now,
                "attributes_json": {"rooms": 4, "area_sqm": 160, "land_sqm": 600, "floors": 2},
            },
        ]

        for ld in listings_data:
            listing = Listing(**ld)
            db.add(listing)
        db.commit()

        # ── Promotion Packages ───────────────────────
        packages = [
            PromotionPackage(
                name_en="Basic Boost", name_ru="Базовое продвижение",
                promotion_type=PromotionType.boosted, duration_days=3, price=5.00,
            ),
            PromotionPackage(
                name_en="Featured 7 Days", name_ru="В топе 7 дней",
                promotion_type=PromotionType.featured, duration_days=7, price=15.00,
            ),
            PromotionPackage(
                name_en="Premium 14 Days", name_ru="Премиум 14 дней",
                promotion_type=PromotionType.top_of_feed, duration_days=14, price=30.00,
            ),
        ]
        db.add_all(packages)
        db.commit()

        print("=" * 50)
        print("DATABASE SEEDED SUCCESSFULLY — NestKG")
        print("=" * 50)
        print(f"Admin:  admin@nestkg.com / admin123")
        print(f"User 1: azamat@example.com / user123")
        print(f"User 2: aigul@example.com / user123")
        print(f"User 3: buyer@example.com / user123")
        print(f"Categories: {len(cats)}")
        print(f"Listings: {len(listings_data)}")
        print(f"Promo packages: {len(packages)}")
        print("=" * 50)

    finally:
        db.close()


if __name__ == "__main__":
    seed()
