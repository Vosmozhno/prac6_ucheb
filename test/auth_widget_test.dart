import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:library_app/main.dart';
import 'package:library_app/core/api_client.dart';
import 'package:library_app/models/app_user.dart';
import 'package:library_app/state/auth_notifier.dart';
import 'support/fake_api.dart';

void main() {
  Future<(AuthNotifier, ApiClient)> prepare({
    String role = 'reader',
    bool wrong = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthNotifier(
      preferences: await SharedPreferences.getInstance(),
    );
    final adapter = FakeApiAdapter((r) {
      if (r.path == '/auth/login') {
        return wrong
            ? reply({}, 401)
            : reply({
                'accessToken': 'test-token',
                'refreshToken': 'test-refresh',
                'user': {
                  'id': 3,
                  'username': 'reader',
                  'fullName': 'Читатель ПР5',
                  'role': role,
                },
              });
      }
      if (r.path == '/books') return reply(pageJson([bookJson()]));
      if (r.path == '/loans') return reply(pageJson([]));
      if (r.path == '/auth/logout') return reply(null, 204);
      return referencesReply(r);
    });
    final dio = buildDio(
      baseUrl: 'http://example.test/api',
      tokenProvider: () => auth.token,
      logger: (_) {},
    );
    dio.httpClientAdapter = adapter;
    final client = ApiClient(dio);
    auth.client = client;
    return (auth, client);
  }

  testWidgets(
    'неавторизованный прямой URL переводится на вход, пароль неверен — понятная ошибка',
    (tester) async {
      final (auth, client) = await prepare(wrong: true);
      await tester.pumpWidget(
        LibraryApp(
          initialLocation: '/books/11',
          apiClient: client,
          apiSession: auth,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Вход в библиотеку'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('auth-username')),
        'reader',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'wrong',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Неверный логин или пароль.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
  testWidgets(
    'у читателя отсутствуют создание, выделение и административная навигация',
    (tester) async {
      final (auth, client) = await prepare();
      await tester.runAsync(() => auth.login('reader', 'reader123'));
      await tester.pumpWidget(
        LibraryApp(
          initialLocation: '/books',
          apiClient: client,
          apiSession: auth,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create-entity')), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Пользователи'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
  testWidgets('ручной адрес формы читателю показывает отказ', (tester) async {
    final (auth, client) = await prepare();
    await tester.runAsync(() => auth.login('reader', 'reader123'));
    await tester.pumpWidget(
      LibraryApp(
        initialLocation: '/books/new',
        apiClient: client,
        apiSession: auth,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Доступ запрещён'), findsOneWidget);
    expect(auth.user!.role, Role.reader);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
  testWidgets(
    'регистрация проверяет пароль во время ввода и помещается на узком экране',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (auth, client) = await prepare();
      await tester.pumpWidget(
        LibraryApp(
          initialLocation: '/register',
          apiClient: client,
          apiSession: auth,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('auth-password')));
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'weak',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Нужно 8 символов, цифра и специальный символ.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password')),
        'Password1!',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Нужно 8 символов, цифра и специальный символ.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
  testWidgets(
    'завершение сессии выводит из изменённой формы без блокирующего диалога',
    (tester) async {
      final (auth, client) = await prepare(role: 'librarian');
      await tester.runAsync(() => auth.login('librarian', 'librarian123'));
      await tester.pumpWidget(
        LibraryApp(
          initialLocation: '/books/new',
          apiClient: client,
          apiSession: auth,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('form-title')),
        'Несохранённая книга',
      );
      await tester.runAsync(
        () => auth.endSession('Сессия завершена из-за бездействия.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Вход в библиотеку'), findsOneWidget);
      expect(find.text('Есть несохранённые изменения'), findsNothing);
      expect(find.text('Сессия завершена из-за бездействия.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
}
