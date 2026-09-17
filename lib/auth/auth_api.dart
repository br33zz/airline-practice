import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import 'auth_models.dart';

class AuthApi {
  final Dio dio;
  const AuthApi(this.dio);

  Future<AuthResult> login(String username, String password) async {
    final response = await guard(
      () => dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'username': username, 'password': password},
      ),
    );
    return AuthResult.fromJson(response.data ?? const {});
  }

  Future<AuthResult> register(
    String name,
    String username,
    String password,
  ) async {
    final response = await guard(
      () => dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {'name': name, 'username': username, 'password': password},
      ),
    );
    return AuthResult.fromJson(response.data ?? const {});
  }

  Future<AuthResult> refresh(String refreshToken) async {
    final response = await guard(
      () => dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      ),
    );
    return AuthResult.fromJson(response.data ?? const {});
  }

  Future<AppUser> me() async {
    final response = await guard(
      () => dio.get<Map<String, dynamic>>('/auth/me'),
    );
    return AppUser.fromJson(response.data ?? const {});
  }
}
