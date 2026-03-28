import 'package:dio/dio.dart';
import '../models/models.dart';

class AuthService {
  final Dio _dio;
  AuthService(this._dio);

  Future<AuthToken> login({required String email, required String password}) async {
    final r = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return AuthToken.fromJson(r.data);
  }

  Future<AuthToken> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
    required String confirmPassword,
    String preferredLanguage = 'en',
  }) async {
    final r = await _dio.post('/auth/register', data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'confirm_password': confirmPassword,
      'preferred_language': preferredLanguage,
    });
    return AuthToken.fromJson(r.data);
  }

  Future<AuthToken> refresh(String refreshToken) async {
    final r = await _dio.post('/auth/refresh', data: {'refresh_token': refreshToken});
    return AuthToken.fromJson(r.data);
  }

  Future<void> changePassword({required String current, required String newPwd}) async {
    await _dio.post('/auth/change-password', data: {'current_password': current, 'new_password': newPwd});
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }
}
