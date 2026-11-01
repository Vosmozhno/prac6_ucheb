import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../repositories/auth_api.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier({
    this.enabled = true,
    this.preferences,
    DateTime Function()? now,
    this.idleTimeout = const Duration(
      seconds: int.fromEnvironment('SESSION_IDLE_SECONDS', defaultValue: 180),
    ),
    this.maxDuration = const Duration(
      seconds: int.fromEnvironment('SESSION_MAX_SECONDS', defaultValue: 1800),
    ),
    this.warningTime = const Duration(
      seconds: int.fromEnvironment('SESSION_WARNING_SECONDS', defaultValue: 30),
    ),
    this.roleDemo = const bool.fromEnvironment('AUTH_ROLE_DEMO'),
  }) : now = now ?? DateTime.now;
  final bool enabled, roleDemo;
  final SharedPreferences? preferences;
  final DateTime Function() now;
  final Duration idleTimeout, maxDuration, warningTime;
  ApiClient? _client;
  ApiClient? get client => _client;
  set client(ApiClient? value) {
    _client = value;
    if (value != null && enabled) {
      value.accessToken = () => token;
      value.onUnauthorized = refreshAfter401;
      value.onSessionExpired = () =>
          endSession('Сессия истекла. Войдите снова.');
    }
  }

  AuthApi get api => AuthApi(_client!);
  AppUser? user;
  String? token, _refreshToken, error, notice;
  Map<String, String> fieldErrors = {};
  bool busy = false, restoring = false, _disposed = false, demoOverride = false;
  DateTime? startedAt, lastActivity, _lastSavedActivity;
  int? warningSeconds;
  int _epoch = 0;
  Future<bool>? _refreshing;
  bool get loggedIn => user != null && token != null;
  bool get isAuthenticated => loggedIn;
  String? get fullName => user?.fullName;
  String? get role => user?.role.value;
  bool allows(Permission permission) =>
      !enabled || (loggedIn && roleAllows(user!.role, permission));
  bool isRole(Role value) => !enabled || (loggedIn && user!.role == value);

  Future<void> restore() async {
    if (!enabled || preferences == null || _client == null) return;
    restoring = true;
    token = preferences!.getString('auth_access_token');
    _refreshToken = preferences!.getString('auth_refresh_token');
    startedAt = _readDate('auth_started_at');
    lastActivity = _readDate('auth_last_activity');
    try {
      if (token == null && _refreshToken == null) return;
      if (startedAt == null ||
          lastActivity == null ||
          _expiredMessage() != null) {
        await endSession(
          _expiredMessage() ?? 'Сессия завершена. Войдите снова.',
        );
        return;
      }
      if (token == null) {
        await refreshAfter401(null);
      } else {
        try {
          user = await api.me();
          await _saveUser();
        } on UnauthorizedException {
          await refreshAfter401(token);
        } on NetworkException {
          final raw = preferences!.getString('auth_user');
          if (raw != null) {
            user = AppUser.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
          }
          notice =
              'Не удалось проверить сессию: сервер недоступен. Повторите загрузку после подключения.';
        }
      }
      final preview = preferences!.getString('auth_ui_role');
      if (roleDemo &&
          user != null &&
          Role.values.any((r) => r.value == preview)) {
        user = user!.withRole(Role.parse(preview));
        demoOverride = true;
      }
      checkSession();
    } on ApiException catch (failure) {
      await endSession(failure.message);
    } on FormatException {
      await endSession('Сохранённая сессия повреждена. Войдите снова.');
    } finally {
      restoring = false;
      _emit();
    }
  }

  Future<void> _accept(AuthResult result) async {
    token = result.access;
    _refreshToken = result.refresh;
    user = result.user;
    await preferences?.setString('auth_access_token', result.access);
    await preferences?.setString('auth_refresh_token', result.refresh);
    await _saveUser();
  }

  DateTime? _readDate(String key) {
    final value = preferences?.getInt(key);
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> _saveUser() async {
    if (user != null) {
      await preferences?.setString('auth_user', jsonEncode(user!.toJson()));
    }
  }

  Future<bool> login(String username, String password) async {
    if (busy || client == null) return false;
    busy = true;
    error = null;
    fieldErrors = {};
    notice = null;
    final generation = ++_epoch;
    _emit();
    try {
      final result = await api.login(username, password);
      if (generation != _epoch) return false;
      startedAt = lastActivity = now();
      demoOverride = false;
      await preferences?.remove('auth_ui_role');
      await _accept(result);
      await preferences?.setInt(
        'auth_started_at',
        startedAt!.millisecondsSinceEpoch,
      );
      await preferences?.setInt(
        'auth_last_activity',
        lastActivity!.millisecondsSinceEpoch,
      );
      return true;
    } on UnauthorizedException {
      error = 'Неверный логин или пароль.';
      return false;
    } on ApiException catch (failure) {
      error = failure.message;
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<bool> register(Map<String, String> values) async {
    if (busy || client == null) return false;
    busy = true;
    error = null;
    fieldErrors = {};
    _emit();
    try {
      await api.register(values);
      notice = 'Регистрация завершена. Войдите с новым логином и паролем.';
      return true;
    } on ValidationException catch (failure) {
      fieldErrors = failure.errors;
      error = failure.message;
      return false;
    } on ApiException catch (failure) {
      error = failure.message;
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<bool> refreshAfter401(String? failedAccess) async {
    if (token != null && token != failedAccess && user != null) return true;
    if (_refreshing != null) return _refreshing!;
    if (_refreshToken == null || client == null) {
      await endSession('Сессия истекла. Войдите снова.');
      return false;
    }
    _refreshing = _performRefresh(_refreshToken!, _epoch);
    try {
      return await _refreshing!;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> _performRefresh(String refresh, int generation) async {
    try {
      final result = await api.refresh(refresh);
      if (generation != _epoch) return false;
      if (_expiredMessage() != null) {
        await endSession(_expiredMessage()!);
        return false;
      }
      await _accept(result);
      _emit();
      return true;
    } on ApiException {
      if (generation == _epoch) {
        await endSession('Не удалось обновить сессию. Войдите снова.');
      }
      return false;
    }
  }

  String? _expiredMessage() {
    final time = now();
    if (startedAt != null && time.difference(startedAt!) >= maxDuration) {
      return 'Время сессии истекло. Войдите снова.';
    }
    if (lastActivity != null && time.difference(lastActivity!) >= idleTimeout) {
      return 'Сессия завершена из-за бездействия. Войдите снова.';
    }
    return null;
  }

  void checkSession() {
    if (!loggedIn) return;
    final message = _expiredMessage();
    if (message != null) {
      unawaited(endSession(message));
      return;
    }
    final remaining = idleTimeout - now().difference(lastActivity ?? now());
    final next = remaining <= warningTime
        ? (remaining.inMilliseconds / 1000).ceil()
        : null;
    if (warningSeconds != next) {
      warningSeconds = next;
      _emit();
    }
  }

  void recordActivity() {
    if (!loggedIn) return;
    if (_expiredMessage() != null) {
      checkSession();
      return;
    }
    lastActivity = now();
    if (_lastSavedActivity == null ||
        now().difference(_lastSavedActivity!) >= const Duration(seconds: 1)) {
      _lastSavedActivity = now();
      unawaited(
        preferences?.setInt(
          'auth_last_activity',
          lastActivity!.millisecondsSinceEpoch,
        ),
      );
    }
    if (warningSeconds != null) {
      warningSeconds = null;
      _emit();
    }
  }

  Future<void> endSession(String message) async {
    final refresh = _refreshToken;
    ++_epoch;
    token = _refreshToken = null;
    user = null;
    warningSeconds = null;
    demoOverride = false;
    notice = message;
    error = null;
    // Update routing immediately; a slow logout request must not keep a screen open.
    _emit();
    for (final key in [
      'auth_access_token',
      'auth_refresh_token',
      'auth_user',
      'auth_ui_role',
      'auth_started_at',
      'auth_last_activity',
    ]) {
      await preferences?.remove(key);
    }
    if (refresh != null && client != null) {
      try {
        await api.logout(refresh);
      } on ApiException {
        /* Local logout always wins. */
      }
    }
  }

  Future<void> logout() => endSession('Вы вышли из системы.');
  void dismissNotice() {
    notice = null;
    _emit();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
