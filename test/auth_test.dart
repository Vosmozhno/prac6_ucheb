import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:library_app/core/api_client.dart';
import 'package:library_app/core/api_exceptions.dart';
import 'package:library_app/core/auth_policy.dart';
import 'package:library_app/models/app_user.dart';
import 'package:library_app/screens/auth_screen.dart';
import 'package:library_app/state/auth_notifier.dart';
import 'support/fake_api.dart';

Map<String, dynamic> authJson([
  String token = 'access-1',
  String role = 'reader',
]) => {
  'accessToken': token,
  'refreshToken': 'refresh-$token',
  'expiresIn': 60,
  'user': {
    'id': 3,
    'username': 'reader',
    'fullName': 'Тестовый читатель',
    'role': role,
  },
};
AuthNotifier makeAuth(
  SharedPreferences prefs,
  FakeApiAdapter adapter, {
  DateTime Function()? now,
  bool roleDemo = false,
}) {
  final auth = AuthNotifier(preferences: prefs, now: now, roleDemo: roleDemo);
  final dio = buildDio(
    baseUrl: 'http://example.test/api',
    tokenProvider: () => auth.token,
    logger: (_) {},
  );
  dio.httpClientAdapter = adapter;
  auth.client = ApiClient(
    dio,
    retryDelays: const [Duration.zero, Duration.zero],
  );
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  final rights = <(Role, Permission, bool)>[
    (Role.reader, Permission.catalog, true),
    (Role.reader, Permission.manageCatalog, false),
    (Role.reader, Permission.renew, true),
    (Role.reader, Permission.users, false),
    (Role.librarian, Permission.manageCatalog, true),
    (Role.librarian, Permission.closeLoan, true),
    (Role.librarian, Permission.hardDelete, false),
    (Role.librarian, Permission.restore, false),
    (Role.admin, Permission.users, true),
    (Role.admin, Permission.statistics, true),
    (Role.admin, Permission.hardDelete, true),
    (Role.admin, Permission.myLoans, false),
  ];
  for (final (role, permission, allowed) in rights) {
    test(
      '${role.value}: ${permission.name} = $allowed',
      () => expect(roleAllows(role, permission), allowed),
    );
  }
  test('у каждой роли есть собственный экран', () {
    for (final role in Role.values) {
      expect(roleCanVisit(role, '/my-loans'), role == Role.reader);
      expect(roleCanVisit(role, '/loans'), role == Role.librarian);
      expect(roleCanVisit(role, '/admin/users'), role == Role.admin);
    }
    expect(roleCanVisit(Role.reader, '/books/new'), false);
    expect(roleCanVisit(Role.reader, '/books/11/edit'), false);
    expect(roleCanVisit(Role.reader, '/readers/4'), false);
  });
  test('возврат после входа безопасен и сохраняет query', () {
    final auth = AuthNotifier();
    expect(
      authRedirect(auth, Uri.parse('/books/11?back=%2Fbooks%3Fpage%3D2')),
      '/login?from=%2Fbooks%2F11%3Fback%3D%252Fbooks%253Fpage%253D2',
    );
    for (final bad in [
      'https://evil.test',
      '//evil.test',
      '/login',
      '/register',
      'books',
    ]) {
      expect(safeReturnPath(bad), '/');
    }
    expect(safeReturnPath('/books?page=2'), '/books?page=2');
    auth.dispose();
  });
  test('правила регистрации: длина, цифра, спецсимвол', () {
    for (final bad in ['', 'Pass!', 'Password!', 'Password1', 'Пароль12 ']) {
      expect(validatePassword(bad), isNotNull);
    }
    expect(validatePassword('Пароль12!'), isNull);
  });
  test('вход сохраняет токены и время, пароль не сохраняется', () async {
    final auth = makeAuth(prefs, FakeApiAdapter((_) => reply(authJson())));
    expect(await auth.login('reader', 'reader123'), true);
    expect(prefs.getString('auth_access_token'), 'access-1');
    expect(prefs.getInt('auth_started_at'), isNotNull);
    expect(prefs.getKeys().any((k) => k.contains('password')), false);
    expect(prefs.getString('auth_user'), isNot(contains('reader123')));
    auth.dispose();
  });
  test('неверный пароль не запускает refresh', () async {
    final adapter = FakeApiAdapter(
      (_) => reply({'message': 'Неверный пароль'}, 401),
    );
    final auth = makeAuth(prefs, adapter);
    expect(await auth.login('reader', 'wrong'), false);
    expect(auth.error, 'Неверный логин или пароль.');
    expect(adapter.requests.length, 1);
    auth.dispose();
  });
  test(
    'перезагрузка восстанавливает пользователя через me, роль не из кэша',
    () async {
      final first = makeAuth(prefs, FakeApiAdapter((_) => reply(authJson())));
      await first.login('reader', 'reader123');
      first.dispose();
      await prefs.setString(
        'auth_user',
        '{"id":3,"username":"reader","fullName":"Подмена","role":"admin"}',
      );
      final adapter = FakeApiAdapter((_) => reply(authJson()['user']));
      final restored = makeAuth(prefs, adapter);
      await restored.restore();
      expect(restored.user!.role, Role.reader);
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer access-1',
      );
      restored.dispose();
    },
  );
  test(
    'одновременные 401 используют один refresh и повторяются с новым Bearer',
    () async {
      final release = Completer<void>();
      var refreshes = 0;
      final adapter = FakeApiAdapter((options) async {
        if (options.path == '/auth/login') return reply(authJson());
        if (options.path == '/auth/refresh') {
          refreshes++;
          await release.future;
          return reply(authJson('access-2'));
        }
        return options.headers['Authorization'] == 'Bearer access-2'
            ? reply({'ok': true})
            : reply({}, 401);
      });
      final auth = makeAuth(prefs, adapter);
      await auth.login('reader', 'reader123');
      final a = auth.client!.request('GET', '/private-a');
      final b = auth.client!.request('GET', '/private-b');
      while (refreshes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait([a, b]);
      expect(refreshes, 1);
      expect(auth.token, 'access-2');
      expect(adapter.requests.where((r) => r.path == '/private-a').length, 2);
      auth.dispose();
    },
  );
  test('ошибка refresh завершает сессию без цикла запросов', () async {
    final adapter = FakeApiAdapter(
      (r) => r.path == '/auth/login'
          ? reply(authJson())
          : r.path == '/auth/logout'
          ? reply(null, 204)
          : reply({}, 401),
    );
    final auth = makeAuth(prefs, adapter);
    await auth.login('reader', 'reader123');
    await expectLater(
      auth.client!.request('GET', '/private'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(auth.loggedIn, false);
    expect(prefs.getString('auth_access_token'), isNull);
    expect(adapter.requests.where((r) => r.path == '/auth/refresh').length, 1);
    expect(adapter.requests.where((r) => r.path == '/private').length, 1);
    auth.dispose();
  });
  test('повторный 401 после успешного refresh тоже не зацикливается', () async {
    final adapter = FakeApiAdapter(
      (r) => r.path == '/auth/login' || r.path == '/auth/refresh'
          ? reply(authJson(r.path == '/auth/login' ? 'access-1' : 'access-2'))
          : r.path == '/auth/logout'
          ? reply(null, 204)
          : reply({}, 401),
    );
    final auth = makeAuth(prefs, adapter);
    await auth.login('reader', 'reader123');
    await expectLater(
      auth.client!.request('POST', '/private'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(auth.loggedIn, false);
    expect(adapter.requests.where((r) => r.path == '/private').length, 2);
    expect(adapter.requests.where((r) => r.path == '/auth/refresh').length, 1);
    auth.dispose();
  });
  test('403 не обновляет токен и не выходит из системы', () async {
    final adapter = FakeApiAdapter(
      (r) => r.path == '/auth/login'
          ? reply(authJson())
          : reply({'message': 'Недостаточно прав'}, 403),
    );
    final auth = makeAuth(prefs, adapter);
    await auth.login('reader', 'reader123');
    await expectLater(
      auth.client!.request('GET', '/users'),
      throwsA(isA<ForbiddenException>()),
    );
    expect(auth.loggedIn, true);
    expect(adapter.requests.length, 2);
    auth.dispose();
  });
  test(
    'предупреждение за 30 секунд, активность сбрасывает только простой',
    () async {
      var time = DateTime(2026, 10, 29, 12);
      final auth = makeAuth(
        prefs,
        FakeApiAdapter((_) => reply(authJson())),
        now: () => time,
      );
      await auth.login('reader', 'reader123');
      time = time.add(const Duration(seconds: 150));
      auth.checkSession();
      expect(auth.warningSeconds, 30);
      auth.recordActivity();
      expect(auth.warningSeconds, isNull);
      final originalStart = auth.startedAt;
      time = time.add(const Duration(seconds: 180));
      auth.checkSession();
      await Future<void>.delayed(Duration.zero);
      expect(auth.loggedIn, false);
      expect(auth.startedAt, originalStart);
      auth.dispose();
    },
  );
  test('общая длительность 30 минут действует даже при активности', () async {
    var time = DateTime(2026, 10, 29, 12);
    final auth = makeAuth(
      prefs,
      FakeApiAdapter((_) => reply(authJson())),
      now: () => time,
    );
    await auth.login('reader', 'reader123');
    for (var n = 0; n < 29; n++) {
      time = time.add(const Duration(minutes: 1));
      auth.recordActivity();
    }
    time = time.add(const Duration(minutes: 1));
    auth.checkSession();
    expect(auth.loggedIn, false);
    expect(auth.notice, contains('Время сессии'));
    auth.dispose();
  });
  test('перезагрузка не обнуляет неактивность', () async {
    var time = DateTime(2026, 10, 29, 12);
    final first = makeAuth(
      prefs,
      FakeApiAdapter((_) => reply(authJson())),
      now: () => time,
    );
    await first.login('reader', 'reader123');
    first.dispose();
    time = time.add(const Duration(minutes: 4));
    final adapter = FakeApiAdapter((_) => reply(null, 204));
    final restored = makeAuth(prefs, adapter, now: () => time);
    await restored.restore();
    expect(restored.loggedIn, false);
    expect(adapter.requests.where((r) => r.path == '/auth/me'), isEmpty);
    restored.dispose();
  });
  test(
    'локальная роль действует только в явно включённом учебном режиме',
    () async {
      final first = makeAuth(prefs, FakeApiAdapter((_) => reply(authJson())));
      await first.login('reader', 'reader123');
      first.dispose();
      await prefs.setString('auth_ui_role', 'admin');
      final normal = makeAuth(
        prefs,
        FakeApiAdapter((_) => reply(authJson()['user'])),
      );
      await normal.restore();
      expect(normal.user!.role, Role.reader);
      normal.dispose();
      final demo = makeAuth(
        prefs,
        FakeApiAdapter((_) => reply(authJson()['user'])),
        roleDemo: true,
      );
      await demo.restore();
      expect(demo.user!.role, Role.admin);
      expect(demo.demoOverride, true);
      expect(demo.token, 'access-1');
      demo.dispose();
    },
  );
  test('запоздалый refresh не восстанавливает сессию после выхода', () async {
    final release = Completer<void>();
    final adapter = FakeApiAdapter((r) async {
      if (r.path == '/auth/login') return reply(authJson());
      if (r.path == '/auth/refresh') {
        await release.future;
        return reply(authJson('late-token'));
      }
      return reply(null, 204);
    });
    final auth = makeAuth(prefs, adapter);
    await auth.login('reader', 'reader123');
    final pending = auth.refreshAfter401(auth.token);
    await auth.logout();
    release.complete();
    expect(await pending, false);
    expect(auth.loggedIn, false);
    expect(prefs.getString('auth_access_token'), isNull);
    auth.dispose();
  });
  test(
    'оставшийся refresh восстанавливает сессию без сброса времени начала',
    () async {
      final first = makeAuth(prefs, FakeApiAdapter((_) => reply(authJson())));
      await first.login('reader', 'reader123');
      first.dispose();
      final start = prefs.getInt('auth_started_at');
      await prefs.remove('auth_access_token');
      final adapter = FakeApiAdapter((_) => reply(authJson('restored-token')));
      final restored = makeAuth(prefs, adapter);
      await restored.restore();
      expect(restored.loggedIn, true);
      expect(prefs.getInt('auth_started_at'), start);
      expect(adapter.requests.single.path, '/auth/refresh');
      restored.dispose();
    },
  );
}
