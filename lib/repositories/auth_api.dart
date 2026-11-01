import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/json_values.dart';

class AuthResult {
  AuthResult.fromJson(Map<String, dynamic> json)
    : access = JsonValues.string(json['accessToken']),
      refresh = JsonValues.string(json['refreshToken']),
      user = AppUser.fromJson(JsonValues.map(json['user'])) {
    if (access.isEmpty || refresh.isEmpty || user.id < 1) {
      throw const ServerException('Сервер вернул неполные данные сессии.');
    }
  }
  final String access, refresh;
  final AppUser user;
}

class AuthApi {
  AuthApi(this.client);
  final ApiClient client;
  Future<AuthResult> login(String username, String password) async =>
      AuthResult.fromJson(
        JsonValues.map(
          (await client.request(
            'POST',
            '/auth/login',
            data: {'username': username.trim(), 'password': password},
          )).data,
        ),
      );
  Future<AuthResult> refresh(String token) async => AuthResult.fromJson(
    JsonValues.map(
      (await client.request(
        'POST',
        '/auth/refresh',
        data: {'refreshToken': token},
      )).data,
    ),
  );
  Future<AppUser> me() async => AppUser.fromJson(
    JsonValues.map((await client.request('GET', '/auth/me')).data),
  );
  Future<void> register(Map<String, String> data) async {
    await client.request('POST', '/auth/register', data: data);
  }

  Future<void> logout(String token) async {
    await client.request('POST', '/auth/logout', data: {'refreshToken': token});
  }
}
