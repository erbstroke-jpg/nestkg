// Helper to safely parse numbers (backend may return String or num)
double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

// ── Auth Token ─────────────────────────────────────

class AuthToken {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const AuthToken({required this.accessToken, required this.refreshToken, this.tokenType = 'bearer'});

  factory AuthToken.fromJson(Map<String, dynamic> j) => AuthToken(
        accessToken: j['access_token'] ?? '',
        refreshToken: j['refresh_token'] ?? '',
        tokenType: j['token_type'] ?? 'bearer',
      );
}

// ── User ──────────────────────────────────────────

class User {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String status;
  final String? profileImageUrl;
  final String? bio;
  final String? city;
  final String preferredLanguage;
  final String createdAt;

  const User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.role = 'user',
    this.status = 'active',
    this.profileImageUrl,
    this.bio,
    this.city,
    this.preferredLanguage = 'en',
    this.createdAt = '',
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] ?? 0,
        fullName: j['full_name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'],
        role: j['role'] ?? 'user',
        status: j['status'] ?? 'active',
        profileImageUrl: j['profile_image_url'],
        bio: j['bio'],
        city: j['city'],
        preferredLanguage: j['preferred_language'] ?? 'en',
        createdAt: j['created_at'] ?? '',
      );
}

class UserPublic {
  final int id;
  final String fullName;
  final String? profileImageUrl;
  final String? bio;
  final String? city;
  final String createdAt;
  final int activeListingsCount;

  const UserPublic({
    required this.id,
    required this.fullName,
    this.profileImageUrl,
    this.bio,
    this.city,
    this.createdAt = '',
    this.activeListingsCount = 0,
  });

  factory UserPublic.fromJson(Map<String, dynamic> j) => UserPublic(
        id: j['id'] ?? 0,
        fullName: j['full_name'] ?? '',
        profileImageUrl: j['profile_image_url'],
        bio: j['bio'],
        city: j['city'],
        createdAt: j['created_at'] ?? '',
        activeListingsCount: j['active_listings_count'] ?? 0,
      );
}

// ── Category ──────────────────────────────────────

class Category {
  final int id;
  final String nameEn;
  final String nameRu;
  final String slug;
  final String? iconUrl;
  final int? parentId;
  final int displayOrder;
  final Map<String, dynamic>? attributesSchema;

  const Category({
    required this.id,
    required this.nameEn,
    required this.nameRu,
    required this.slug,
    this.iconUrl,
    this.parentId,
    this.displayOrder = 0,
    this.attributesSchema,
  });

  String name(String lang) => lang == 'ru' ? nameRu : nameEn;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] ?? 0,
        nameEn: j['name_en'] ?? '',
        nameRu: j['name_ru'] ?? '',
        slug: j['slug'] ?? '',
        iconUrl: j['icon_url'],
        parentId: j['parent_id'],
        displayOrder: j['display_order'] ?? 0,
        attributesSchema: j['attributes_schema'],
      );
}

// ── Listing Media ─────────────────────────────────

class ListingMedia {
  final int id;
  final String fileUrl;
  final String originalName;
  final String mimeType;
  final int displayOrder;
  final bool isPrimary;

  const ListingMedia({
    required this.id,
    required this.fileUrl,
    this.originalName = '',
    this.mimeType = '',
    this.displayOrder = 0,
    this.isPrimary = false,
  });

  factory ListingMedia.fromJson(Map<String, dynamic> j) => ListingMedia(
        id: j['id'] ?? 0,
        fileUrl: j['file_url'] ?? '',
        originalName: j['original_name'] ?? '',
        mimeType: j['mime_type'] ?? '',
        displayOrder: j['display_order'] ?? 0,
        isPrimary: j['is_primary'] ?? false,
      );
}

// ── Listing Owner (embedded) ──────────────────────

class ListingOwner {
  final int id;
  final String fullName;
  final String? profileImageUrl;
  final String? city;

  const ListingOwner({required this.id, required this.fullName, this.profileImageUrl, this.city});

  factory ListingOwner.fromJson(Map<String, dynamic> j) => ListingOwner(
        id: j['id'] ?? 0,
        fullName: j['full_name'] ?? '',
        profileImageUrl: j['profile_image_url'],
        city: j['city'],
      );
}

// ── Listing Category (embedded) ───────────────────

class ListingCategory {
  final int id;
  final String nameEn;
  final String nameRu;
  final String slug;

  const ListingCategory({required this.id, required this.nameEn, required this.nameRu, required this.slug});

  String name(String lang) => lang == 'ru' ? nameRu : nameEn;

  factory ListingCategory.fromJson(Map<String, dynamic> j) => ListingCategory(
        id: j['id'] ?? 0,
        nameEn: j['name_en'] ?? '',
        nameRu: j['name_ru'] ?? '',
        slug: j['slug'] ?? '',
      );
}

// ── Listing ───────────────────────────────────────

class Listing {
  final int id;
  final int ownerId;
  final int categoryId;
  final String title;
  final String description;
  final double price;
  final String currency;
  final String city;
  final double? latitude;
  final double? longitude;
  final String? condition;
  final bool isNegotiable;
  final String contactPreference;
  final String status;
  final int viewCount;
  final Map<String, dynamic>? attributesJson;
  final String createdAt;
  final String? publishedAt;
  final List<ListingMedia> media;
  final ListingOwner? owner;
  final ListingCategory? category;
  final bool isFavorited;
  final bool isPromoted;

  const Listing({
    required this.id,
    required this.ownerId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.price,
    this.currency = 'USD',
    required this.city,
    this.latitude,
    this.longitude,
    this.condition,
    this.isNegotiable = false,
    this.contactPreference = 'chat',
    this.status = 'draft',
    this.viewCount = 0,
    this.attributesJson,
    this.createdAt = '',
    this.publishedAt,
    this.media = const [],
    this.owner,
    this.category,
    this.isFavorited = false,
    this.isPromoted = false,
  });

  String? get primaryImageUrl {
    if (media.isEmpty) return null;
    final primary = media.where((m) => m.isPrimary).firstOrNull;
    return (primary ?? media.first).fileUrl;
  }

  Listing copyWith({bool? isFavorited}) => Listing(
        id: id, ownerId: ownerId, categoryId: categoryId, title: title,
        description: description, price: price, currency: currency, city: city,
        latitude: latitude, longitude: longitude, condition: condition,
        isNegotiable: isNegotiable, contactPreference: contactPreference,
        status: status, viewCount: viewCount, attributesJson: attributesJson,
        createdAt: createdAt, publishedAt: publishedAt, media: media,
        owner: owner, category: category,
        isFavorited: isFavorited ?? this.isFavorited, isPromoted: isPromoted,
      );

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] ?? 0,
        ownerId: j['owner_id'] ?? 0,
        categoryId: j['category_id'] ?? 0,
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        price: _toDouble(j['price']) ?? 0,
        currency: j['currency'] ?? 'USD',
        city: j['city'] ?? '',
        latitude: _toDouble(j['latitude']),
        longitude: _toDouble(j['longitude']),
        condition: j['condition'],
        isNegotiable: j['is_negotiable'] ?? false,
        contactPreference: j['contact_preference'] ?? 'chat',
        status: j['status'] ?? 'draft',
        viewCount: j['view_count'] ?? 0,
        attributesJson: j['attributes_json'],
        createdAt: j['created_at'] ?? '',
        publishedAt: j['published_at'],
        media: (j['media'] as List?)?.map((m) => ListingMedia.fromJson(m)).toList() ?? [],
        owner: j['owner'] != null ? ListingOwner.fromJson(j['owner']) : null,
        category: j['category'] != null ? ListingCategory.fromJson(j['category']) : null,
        isFavorited: j['is_favorited'] ?? false,
        isPromoted: j['is_promoted'] ?? false,
      );
}

// ── Paginated Response ────────────────────────────

class PaginatedResponse<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  const PaginatedResponse({
    required this.items,
    this.page = 1,
    this.pageSize = 20,
    this.totalItems = 0,
    this.totalPages = 0,
  });

  bool get hasMore => page < totalPages;
}

// ── Conversation ──────────────────────────────────

class ConversationParticipant {
  final int id;
  final String fullName;
  final String? profileImageUrl;

  const ConversationParticipant({required this.id, required this.fullName, this.profileImageUrl});

  factory ConversationParticipant.fromJson(Map<String, dynamic> j) => ConversationParticipant(
        id: j['id'] ?? 0,
        fullName: j['full_name'] ?? '',
        profileImageUrl: j['profile_image_url'],
      );
}

class Conversation {
  final int id;
  final int? listingId;
  final ConversationParticipant participantA;
  final ConversationParticipant participantB;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final int unreadCount;
  final String createdAt;

  const Conversation({
    required this.id,
    this.listingId,
    required this.participantA,
    required this.participantB,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.createdAt = '',
  });

  ConversationParticipant otherParticipant(int myId) =>
      participantA.id == myId ? participantB : participantA;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] ?? 0,
        listingId: j['listing_id'],
        participantA: ConversationParticipant.fromJson(j['participant_a'] ?? {}),
        participantB: ConversationParticipant.fromJson(j['participant_b'] ?? {}),
        lastMessageAt: j['last_message_at'],
        lastMessagePreview: j['last_message_preview'],
        unreadCount: j['unread_count'] ?? 0,
        createdAt: j['created_at'] ?? '',
      );
}

// ── Message ───────────────────────────────────────

class MessageAttachment {
  final int id;
  final String fileName;
  final String originalName;
  final String mimeType;
  final int fileSize;
  final String fileUrl;

  const MessageAttachment({
    required this.id,
    this.fileName = '',
    this.originalName = '',
    this.mimeType = '',
    this.fileSize = 0,
    this.fileUrl = '',
  });

  bool get isImage => mimeType.startsWith('image/');

  factory MessageAttachment.fromJson(Map<String, dynamic> j) => MessageAttachment(
        id: j['id'] ?? 0,
        fileName: j['file_name'] ?? '',
        originalName: j['original_name'] ?? '',
        mimeType: j['mime_type'] ?? '',
        fileSize: j['file_size'] ?? 0,
        fileUrl: j['file_url'] ?? '',
      );
}

class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String? textBody;
  final String messageType;
  final bool isRead;
  final String sentAt;
  final List<MessageAttachment> attachments;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.textBody,
    this.messageType = 'text',
    this.isRead = false,
    this.sentAt = '',
    this.attachments = const [],
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] ?? 0,
        conversationId: j['conversation_id'] ?? 0,
        senderId: j['sender_id'] ?? 0,
        textBody: j['text_body'],
        messageType: j['message_type'] ?? 'text',
        isRead: j['is_read'] ?? false,
        sentAt: j['sent_at'] ?? '',
        attachments: (j['attachments'] as List?)
                ?.map((a) => MessageAttachment.fromJson(a))
                .toList() ??
            [],
      );
}

// ── Notification ──────────────────────────────────

class AppNotification {
  final int id;
  final String type;
  final String title;
  final String? body;
  final String? referenceType;
  final int? referenceId;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.referenceType,
    this.referenceId,
    this.isRead = false,
    this.createdAt = '',
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] ?? 0,
        type: j['type'] ?? '',
        title: j['title'] ?? '',
        body: j['body'],
        referenceType: j['reference_type'],
        referenceId: j['reference_id'],
        isRead: j['is_read'] ?? false,
        createdAt: j['created_at'] ?? '',
      );
}

// ── Report ────────────────────────────────────────

class Report {
  final int id;
  final String targetType;
  final int targetId;
  final String reasonCode;
  final String? reasonText;
  final String status;
  final String createdAt;

  const Report({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reasonCode,
    this.reasonText,
    this.status = 'pending',
    this.createdAt = '',
  });

  factory Report.fromJson(Map<String, dynamic> j) => Report(
        id: j['id'] ?? 0,
        targetType: j['target_type'] ?? '',
        targetId: j['target_id'] ?? 0,
        reasonCode: j['reason_code'] ?? '',
        reasonText: j['reason_text'],
        status: j['status'] ?? 'pending',
        createdAt: j['created_at'] ?? '',
      );
}

// ── Payment ───────────────────────────────────────

class Payment {
  final int id;
  final int userId;
  final int? listingId;
  final double amount;
  final String currency;
  final String status;
  final String paymentProvider;
  final String? providerReference;
  final String createdAt;
  final String? paidAt;

  const Payment({
    required this.id,
    required this.userId,
    this.listingId,
    required this.amount,
    this.currency = 'USD',
    this.status = 'pending',
    this.paymentProvider = 'mock',
    this.providerReference,
    this.createdAt = '',
    this.paidAt,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] ?? 0,
        userId: j['user_id'] ?? 0,
        listingId: j['listing_id'],
        amount: _toDouble(j['amount']) ?? 0,
        currency: j['currency'] ?? 'USD',
        status: j['status'] ?? 'pending',
        paymentProvider: j['payment_provider'] ?? 'mock',
        providerReference: j['provider_reference'],
        createdAt: j['created_at'] ?? '',
        paidAt: j['paid_at'],
      );
}

// ── Promotion Package ─────────────────────────────

class PromotionPackage {
  final int id;
  final String nameEn;
  final String nameRu;
  final String promotionType;
  final int durationDays;
  final double price;
  final String currency;

  const PromotionPackage({
    required this.id,
    required this.nameEn,
    required this.nameRu,
    required this.promotionType,
    required this.durationDays,
    required this.price,
    this.currency = 'USD',
  });

  String name(String lang) => lang == 'ru' ? nameRu : nameEn;

  factory PromotionPackage.fromJson(Map<String, dynamic> j) => PromotionPackage(
        id: j['id'] ?? 0,
        nameEn: j['name_en'] ?? '',
        nameRu: j['name_ru'] ?? '',
        promotionType: j['promotion_type'] ?? '',
        durationDays: j['duration_days'] ?? 0,
        price: _toDouble(j['price']) ?? 0,
        currency: j['currency'] ?? 'USD',
      );
}

// ── Promotion ─────────────────────────────────────

class Promotion {
  final int id;
  final int listingId;
  final String promotionType;
  final String? targetCity;
  final int? targetCategoryId;
  final String? startsAt;
  final String? endsAt;
  final String status;
  final double purchasedPrice;
  final int? paymentId;
  final String createdAt;

  const Promotion({
    required this.id,
    required this.listingId,
    required this.promotionType,
    this.targetCity,
    this.targetCategoryId,
    this.startsAt,
    this.endsAt,
    this.status = 'pending_payment',
    required this.purchasedPrice,
    this.paymentId,
    this.createdAt = '',
  });

  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
        id: j['id'] ?? 0,
        listingId: j['listing_id'] ?? 0,
        promotionType: j['promotion_type'] ?? '',
        targetCity: j['target_city'],
        targetCategoryId: j['target_category_id'],
        startsAt: j['starts_at'],
        endsAt: j['ends_at'],
        status: j['status'] ?? 'pending_payment',
        purchasedPrice: _toDouble(j['purchased_price']) ?? 0,
        paymentId: j['payment_id'],
        createdAt: j['created_at'] ?? '',
      );
}
