import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_api.dart';
import '../auth/auth_models.dart';
import '../core/api_exceptions.dart';

class AuthNotifier extends ChangeNotifier {
  static const accessKey = 'airline_auth_access_token';
  static const refreshKey = 'airline_auth_refresh_token';
  static const userKey = 'airline_auth_user';
  static const lastActivityKey = 'airline_auth_last_activity';
  static const sessionStartedKey = 'airline_auth_session_started';

  final SharedPreferences prefs;
  final AuthApi api;
  AppUser? _user;
  String? _accessToken;
  String? _refreshToken;
  String? _notice;
  bool _restoring = true;
  Future<void>? _refreshFuture;

  AuthNotifier(this.prefs, this.api);

  AppUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _user != null && _accessToken != null;
  bool get restoring => _restoring;
  String? get notice => _notice;
  bool has(AppPermission permission) =>
      _user != null && roleHas(_user!.role, permission);

  DateTime? get lastActivity => _readDate(lastActivityKey);
  DateTime? get sessionStarted => _readDate(sessionStartedKey);

  Future<void> restore() async {
    _accessToken = prefs.getString(accessKey);
    _refreshToken = prefs.getString(refreshKey);
    final cached = prefs.getString(userKey);
    if (cached != null) {
      try {
        _user = AppUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
      } catch (_) {
        _user = null;
      }
    }
    if (_accessToken != null && _user != null) {
      try {
        await api.me();
      } on UnauthorizedException {
        try {
          await refreshTokens();
        } catch (_) {
          await logout();
        }
      } catch (_) {
        // При временной недоступности сервера сохранённая сессия остаётся.
      }
    } else {
      await _clearSession();
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async =>
      _accept(await api.login(username.trim(), password));

  Future<void> register(String name, String username, String password) async =>
      _accept(await api.register(name.trim(), username.trim(), password));

  Future<void> refreshTokens() => _refreshFuture ??= (() async {
    final token = _refreshToken ?? prefs.getString(refreshKey);
    if (token == null) throw const UnauthorizedException();
    final result = await api.refresh(token);
    await _accept(result, newSession: false);
  })().whenComplete(() => _refreshFuture = null);

  Future<void> logout({String? reason}) async {
    await _clearSession();
    _notice = reason;
    notifyListeners();
  }

  String? takeNotice() {
    final value = _notice;
    _notice = null;
    return value;
  }

  Future<void> recordActivity() => prefs.setString(
    lastActivityKey,
    DateTime.now().toUtc().toIso8601String(),
  );

  Future<void> _accept(AuthResult result, {bool newSession = true}) async {
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _user = result.user;
    final now = DateTime.now().toUtc().toIso8601String();
    await Future.wait([
      prefs.setString(accessKey, result.accessToken),
      prefs.setString(refreshKey, result.refreshToken),
      prefs.setString(userKey, jsonEncode(result.user.toJson())),
      prefs.setString(lastActivityKey, now),
      if (newSession) prefs.setString(sessionStartedKey, now),
    ]);
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    await Future.wait([
      prefs.remove(accessKey),
      prefs.remove(refreshKey),
      prefs.remove(userKey),
      prefs.remove(lastActivityKey),
      prefs.remove(sessionStartedKey),
    ]);
  }

  DateTime? _readDate(String key) =>
      DateTime.tryParse(prefs.getString(key) ?? '')?.toLocal();
}
