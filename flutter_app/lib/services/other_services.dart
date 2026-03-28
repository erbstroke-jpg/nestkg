import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/models.dart';

// ── User Service ──────────────────────────────────

class UserService {
  final Dio _dio;
  UserService(this._dio);

  Future<User> getMe() async {
    final r = await _dio.get('/users/me');
    return User.fromJson(r.data);
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final r = await _dio.put('/users/me', data: data);
    return User.fromJson(r.data);
  }

  Future<User> uploadAvatar(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final r = await _dio.put('/users/me/avatar', data: formData);
    return User.fromJson(r.data);
  }

  Future<UserPublic> getPublicProfile(int userId) async {
    final r = await _dio.get('/users/$userId/public');
    return UserPublic.fromJson(r.data);
  }

  Future<PaginatedResponse<Listing>> getUserListings(int userId, {int page = 1}) async {
    final r = await _dio.get('/users/$userId/listings', queryParameters: {'page': page, 'page_size': 20});
    final items = (r.data['items'] as List?)?.map((j) => Listing.fromJson(j)).toList() ?? [];
    return PaginatedResponse(
      items: items, page: r.data['page'] ?? 1, pageSize: 20,
      totalItems: r.data['total_items'] ?? 0, totalPages: r.data['total_pages'] ?? 0,
    );
  }
}

// ── Favorites Service ─────────────────────────────

class FavoritesService {
  final Dio _dio;
  FavoritesService(this._dio);

  Future<void> add(int listingId) async => await _dio.post('/favorites/$listingId');
  Future<void> remove(int listingId) async => await _dio.delete('/favorites/$listingId');

  Future<PaginatedResponse<Listing>> getAll({int page = 1}) async {
    final r = await _dio.get('/favorites', queryParameters: {'page': page, 'page_size': 20});
    final items = (r.data['items'] as List?)?.map((j) => Listing.fromJson(j)).toList() ?? [];
    return PaginatedResponse(
      items: items, page: r.data['page'] ?? 1, pageSize: 20,
      totalItems: r.data['total_items'] ?? 0, totalPages: r.data['total_pages'] ?? 0,
    );
  }
}

// ── Categories Service ────────────────────────────

class CategoriesService {
  final Dio _dio;
  CategoriesService(this._dio);

  Future<List<Category>> getAll() async {
    final r = await _dio.get('/categories');
    return (r.data as List).map((j) => Category.fromJson(j)).toList();
  }
}

// ── Messaging Service ─────────────────────────────

class MessagingService {
  final Dio _dio;
  MessagingService(this._dio);

  Future<PaginatedResponse<Conversation>> getConversations({int page = 1}) async {
    final r = await _dio.get('/conversations', queryParameters: {'page': page, 'page_size': 20});
    final items = (r.data['items'] as List?)?.map((j) => Conversation.fromJson(j)).toList() ?? [];
    return PaginatedResponse(
      items: items, page: r.data['page'] ?? 1, pageSize: 20,
      totalItems: r.data['total_items'] ?? 0, totalPages: r.data['total_pages'] ?? 0,
    );
  }

  Future<Conversation> createConversation({
    required int listingId,
    required int recipientId,
    String? initialMessage,
  }) async {
    final r = await _dio.post('/conversations', data: {
      'listing_id': listingId,
      'recipient_id': recipientId,
      'initial_message': initialMessage,
    });
    return Conversation.fromJson(r.data);
  }

  Future<PaginatedResponse<Message>> getMessages(int conversationId, {int page = 1}) async {
    final r = await _dio.get('/conversations/$conversationId/messages',
        queryParameters: {'page': page, 'page_size': 50});
    final items = (r.data['items'] as List?)?.map((j) => Message.fromJson(j)).toList() ?? [];
    return PaginatedResponse(
      items: items, page: r.data['page'] ?? 1, pageSize: 50,
      totalItems: r.data['total_items'] ?? 0, totalPages: r.data['total_pages'] ?? 0,
    );
  }

  Future<Message> sendMessage(int conversationId, String text) async {
    final r = await _dio.post('/conversations/$conversationId/messages', data: {'text_body': text});
    return Message.fromJson(r.data);
  }

  Future<Message> sendMessageWithAttachmentBytes(int conversationId, Uint8List bytes, String filename, {String? textBody}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      if (textBody != null) 'text_body': textBody,
    });
    final r = await _dio.post('/conversations/$conversationId/messages-with-attachment', data: formData);
    return Message.fromJson(r.data);
  }
}

// ── Notifications Service ─────────────────────────

class NotificationsService {
  final Dio _dio;
  NotificationsService(this._dio);

  Future<PaginatedResponse<AppNotification>> getAll({int page = 1}) async {
    final r = await _dio.get('/notifications', queryParameters: {'page': page, 'page_size': 20});
    final items = (r.data['items'] as List?)?.map((j) => AppNotification.fromJson(j)).toList() ?? [];
    return PaginatedResponse(
      items: items, page: r.data['page'] ?? 1, pageSize: 20,
      totalItems: r.data['total_items'] ?? 0, totalPages: r.data['total_pages'] ?? 0,
    );
  }

  Future<int> getUnreadCount() async {
    final r = await _dio.get('/notifications/unread-count');
    return r.data['unread_count'] ?? 0;
  }

  Future<void> markRead(int id) async => await _dio.put('/notifications/$id/read');
  Future<void> markAllRead() async => await _dio.put('/notifications/read-all');
}

// ── Reports Service ───────────────────────────────

class ReportsService {
  final Dio _dio;
  ReportsService(this._dio);

  Future<Report> create({
    required String targetType,
    required int targetId,
    required String reasonCode,
    String? reasonText,
  }) async {
    final r = await _dio.post('/reports', data: {
      'target_type': targetType,
      'target_id': targetId,
      'reason_code': reasonCode,
      'reason_text': reasonText,
    });
    return Report.fromJson(r.data);
  }
}

// ── Payments Service ──────────────────────────────

class PaymentsService {
  final Dio _dio;
  PaymentsService(this._dio);

  Future<PaginatedResponse<Payment>> getMyPayments({int page = 1}) async {
    final r = await _dio.get('/payments/my', queryParameters: {'page': page, 'page_size': 20});
    final items = (r.data['items'] as List?)?.map((j) => Payment.fromJson(j)).toList() ?? [];
    return PaginatedResponse(
      items: items, page: r.data['page'] ?? 1, pageSize: 20,
      totalItems: r.data['total_items'] ?? 0, totalPages: r.data['total_pages'] ?? 0,
    );
  }

  Future<Payment> confirm(int paymentId, {bool success = true}) async {
    final r = await _dio.post('/payments/$paymentId/confirm', data: {'success': success});
    return Payment.fromJson(r.data);
  }
}

// ── Promotions Service ────────────────────────────

class PromotionsService {
  final Dio _dio;
  PromotionsService(this._dio);

  Future<List<PromotionPackage>> getPackages() async {
    final r = await _dio.get('/promotion-packages');
    return (r.data as List).map((j) => PromotionPackage.fromJson(j)).toList();
  }

  Future<Promotion> purchase({
    required int listingId,
    required int packageId,
    String? targetCity,
    int? targetCategoryId,
  }) async {
    final r = await _dio.post('/promotions/purchase', data: {
      'listing_id': listingId,
      'package_id': packageId,
      'target_city': targetCity,
      'target_category_id': targetCategoryId,
    });
    return Promotion.fromJson(r.data);
  }

  Future<PaginatedResponse<Promotion>> getMyPromotions({int page = 1}) async {
    final r = await _dio.get('/promotions/my', queryParameters: {'page': page, 'page_size': 20});
    final items = (r.data['items'] as List?)?.map((j) => Promotion.fromJson(j)).toList() ?? [];
    return PaginatedResponse(
      items: items, page: r.data['page'] ?? 1, pageSize: 20,
      totalItems: r.data['total_items'] ?? 0, totalPages: r.data['total_pages'] ?? 0,
    );
  }
}
