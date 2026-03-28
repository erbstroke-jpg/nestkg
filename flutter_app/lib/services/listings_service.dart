import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/models.dart';

class ListingsService {
  final Dio _dio;
  ListingsService(this._dio);

  Future<PaginatedResponse<Listing>> fetchFeed({
    int page = 1, int pageSize = 20, String? search, int? categoryId, String? city,
    double? minPrice, double? maxPrice, String? condition, String sortBy = 'newest',
  }) async {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize, 'sort_by': sortBy};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = categoryId;
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (minPrice != null) params['min_price'] = minPrice;
    if (maxPrice != null) params['max_price'] = maxPrice;
    if (condition != null) params['condition'] = condition;
    final r = await _dio.get('/listings', queryParameters: params);
    return _parsePaginated(r.data);
  }

  Future<Listing> getById(int id) async {
    final r = await _dio.get('/listings/$id');
    return Listing.fromJson(r.data);
  }

  Future<PaginatedResponse<Listing>> getMyListings({int page = 1, String? statusFilter}) async {
    final params = <String, dynamic>{'page': page, 'page_size': 20};
    if (statusFilter != null) params['status_filter'] = statusFilter;
    final r = await _dio.get('/listings/my/all', queryParameters: params);
    return _parsePaginated(r.data);
  }

  Future<Listing> create({
    required int categoryId, required String title, required String description,
    required double price, String currency = 'USD', required String city,
    double? latitude, double? longitude, String? condition, bool isNegotiable = false,
    String contactPreference = 'chat', Map<String, dynamic>? attributesJson, bool submitForReview = false,
  }) async {
    final body = <String, dynamic>{
      'category_id': categoryId, 'title': title, 'description': description,
      'price': price, 'currency': currency, 'city': city,
      'condition': condition, 'is_negotiable': isNegotiable,
      'contact_preference': contactPreference, 'submit_for_review': submitForReview,
    };
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (attributesJson != null) body['attributes_json'] = attributesJson;
    final r = await _dio.post('/listings', data: body);
    return Listing.fromJson(r.data);
  }

  Future<Listing> update(int id, Map<String, dynamic> data) async {
    final r = await _dio.put('/listings/$id', data: data);
    return Listing.fromJson(r.data);
  }

  Future<void> delete(int id) async => await _dio.delete('/listings/$id');
  Future<void> submitForReview(int id) async => await _dio.post('/listings/$id/submit');
  Future<void> markSold(int id) async => await _dio.post('/listings/$id/mark-sold');

  /// Upload media using bytes (works on Web + Mobile)
  Future<ListingMedia> uploadMediaBytes(int listingId, Uint8List bytes, String filename, {bool isPrimary = false}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'is_primary': isPrimary,
    });
    final r = await _dio.post('/listings/$listingId/media', data: formData);
    return ListingMedia.fromJson(r.data);
  }

  Future<void> deleteMedia(int mediaId) async => await _dio.delete('/listings/media/$mediaId');

  PaginatedResponse<Listing> _parsePaginated(dynamic data) {
    final items = (data['items'] as List?)?.map((j) => Listing.fromJson(j)).toList() ?? [];
    return PaginatedResponse(items: items, page: data['page'] ?? 1, pageSize: data['page_size'] ?? 20,
      totalItems: data['total_items'] ?? 0, totalPages: data['total_pages'] ?? 0);
  }
}
