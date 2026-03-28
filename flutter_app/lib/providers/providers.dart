import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/listings_service.dart';
import '../services/other_services.dart';

// ── Service Providers ─────────────────────────────

final authServiceProvider =
    Provider((ref) => AuthService(ref.read(dioProvider)));
final listingsServiceProvider =
    Provider((ref) => ListingsService(ref.read(dioProvider)));
final userServiceProvider =
    Provider((ref) => UserService(ref.read(dioProvider)));
final favoritesServiceProvider =
    Provider((ref) => FavoritesService(ref.read(dioProvider)));
final categoriesServiceProvider =
    Provider((ref) => CategoriesService(ref.read(dioProvider)));
final messagingServiceProvider =
    Provider((ref) => MessagingService(ref.read(dioProvider)));
final notificationsServiceProvider =
    Provider((ref) => NotificationsService(ref.read(dioProvider)));
final reportsServiceProvider =
    Provider((ref) => ReportsService(ref.read(dioProvider)));
final paymentsServiceProvider =
    Provider((ref) => PaymentsService(ref.read(dioProvider)));
final promotionsServiceProvider =
    Provider((ref) => PromotionsService(ref.read(dioProvider)));

// ── Locale Provider ───────────────────────────────

final localeProvider =
    StateNotifierProvider<LocaleNotifier, String>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier() : super('en') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('locale') ?? 'en';
  }

  Future<void> setLocale(String locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
  }
}

// ── Auth Provider ─────────────────────────────────

class AuthState {
  final bool isLoading;
  final String? error;
  final AuthToken? token;
  final User? user;

  const AuthState({this.isLoading = false, this.error, this.token, this.user});
  bool get isAuthenticated => token != null;

  AuthState copyWith(
          {bool? isLoading, String? error, AuthToken? token, User? user}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        token: token ?? this.token,
        user: user ?? this.user,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(const AuthState());

  Future<void> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString('access_token');
    final refresh = prefs.getString('refresh_token');
    if (access != null && access.isNotEmpty) {
      ref.read(accessTokenProvider.notifier).state = access;
      state = AuthState(
          token: AuthToken(accessToken: access, refreshToken: refresh ?? ''));
      try {
        final user = await ref.read(userServiceProvider).getMe();
        state = state.copyWith(user: user);
      } catch (_) {
        // Token expired — try refresh
        if (refresh != null) {
          try {
            final newToken =
                await ref.read(authServiceProvider).refresh(refresh);
            await _saveTokens(newToken);
            ref.read(accessTokenProvider.notifier).state = newToken.accessToken;
            state = AuthState(token: newToken);
            final user = await ref.read(userServiceProvider).getMe();
            state = state.copyWith(user: user);
          } catch (_) {
            await _clearTokens();
            state = const AuthState();
          }
        } else {
          await _clearTokens();
          state = const AuthState();
        }
      }
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await ref
          .read(authServiceProvider)
          .login(email: email, password: password);
      await _saveTokens(token);
      ref.read(accessTokenProvider.notifier).state = token.accessToken;
      final user = await ref.read(userServiceProvider).getMe();
      state = AuthState(token: token, user: user);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: dioError(e));
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
    required String confirmPassword,
    String preferredLanguage = 'en',
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final token = await ref.read(authServiceProvider).register(
            fullName: fullName,
            email: email,
            phone: phone,
            password: password,
            confirmPassword: confirmPassword,
            preferredLanguage: preferredLanguage,
          );
      await _saveTokens(token);
      ref.read(accessTokenProvider.notifier).state = token.accessToken;
      final user = await ref.read(userServiceProvider).getMe();
      state = AuthState(token: token, user: user);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: dioError(e));
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await ref.read(userServiceProvider).getMe();
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<void> logout() async {
    await _clearTokens();
    ref.read(accessTokenProvider.notifier).state = null;
    state = const AuthState();
  }

  Future<void> _saveTokens(AuthToken t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', t.accessToken);
    await prefs.setString('refresh_token', t.refreshToken);
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));

// ── Categories Provider ───────────────────────────

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.read(categoriesServiceProvider).getAll();
});

// ── Listings Feed Provider (with filters) ─────────

class FeedFilter {
  final String? search;
  final int? categoryId;
  final String? city;
  final double? minPrice;
  final double? maxPrice;
  final String? condition;
  final String sortBy;

  const FeedFilter({
    this.search,
    this.categoryId,
    this.city,
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.sortBy = 'newest',
  });

  FeedFilter copyWith({
    String? search,
    int? categoryId,
    String? city,
    double? minPrice,
    double? maxPrice,
    String? condition,
    String? sortBy,
    bool clearCategory = false,
    bool clearCity = false,
    bool clearCondition = false,
    bool clearSearch = false,
    bool clearPrice = false,
  }) =>
      FeedFilter(
        search: clearSearch ? null : (search ?? this.search),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        city: clearCity ? null : (city ?? this.city),
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        condition: clearCondition ? null : (condition ?? this.condition),
        sortBy: sortBy ?? this.sortBy,
      );
}

final feedFilterProvider =
    StateProvider<FeedFilter>((ref) => const FeedFilter());

final feedProvider =
    FutureProvider.family<PaginatedResponse<Listing>, int>((ref, page) async {
  final filter = ref.watch(feedFilterProvider);
  return ref.read(listingsServiceProvider).fetchFeed(
        page: page,
        search: filter.search,
        categoryId: filter.categoryId,
        city: filter.city,
        minPrice: filter.minPrice,
        maxPrice: filter.maxPrice,
        condition: filter.condition,
        sortBy: filter.sortBy,
      );
});

// ── Favorites Provider ────────────────────────────

final favoritesProvider =
    FutureProvider.autoDispose<PaginatedResponse<Listing>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return PaginatedResponse(
        items: [], page: 1, pageSize: 20, totalItems: 0, totalPages: 0);
  }
  return await ref.read(favoritesServiceProvider).getAll();
});

// ── Conversations Provider ────────────────────────

final conversationsProvider =
    FutureProvider.autoDispose<PaginatedResponse<Conversation>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return PaginatedResponse(
        items: [], page: 1, pageSize: 20, totalItems: 0, totalPages: 0);
  }
  return await ref.read(messagingServiceProvider).getConversations();
});

// ── Notifications Provider ────────────────────────

final notificationsProvider =
    FutureProvider.autoDispose<PaginatedResponse<AppNotification>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return PaginatedResponse(
        items: [], page: 1, pageSize: 20, totalItems: 0, totalPages: 0);
  }
  return await ref.read(notificationsServiceProvider).getAll();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return 0;
  try {
    return await ref.read(notificationsServiceProvider).getUnreadCount();
  } catch (e) {
    return 0;
  }
});

// ── Promotion Packages ────────────────────────────

final promotionPackagesProvider =
    FutureProvider<List<PromotionPackage>>((ref) async {
  return ref.read(promotionsServiceProvider).getPackages();
});
