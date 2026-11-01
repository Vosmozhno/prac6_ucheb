import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/main.dart';
import 'package:library_app/models/library_snapshot.dart';
import 'package:library_app/state/auth_notifier.dart';
import 'package:library_app/core/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_api.dart';

void viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ResponseBody screenReply(RequestOptions r) {
  final seed = LibrarySnapshot.seed();
  if (r.path == '/auth/login') {
    final role = (r.data as Map)['username'];
    return reply({
      'accessToken': 'test-access',
      'refreshToken': 'test-refresh',
      'user': {
        'id': 1,
        'username': role,
        'fullName': 'Проверка адаптивности',
        'role': role,
      },
    });
  }
  if (r.path == '/stats') {
    return reply({
      'books': 20,
      'readers': 6,
      'users': 3,
      'activeLoans': 2,
      'overdueLoans': 1,
    });
  }
  if (r.path == '/users') {
    return reply(
      pageJson([
        {
          'id': 2,
          'username': 'librarian',
          'fullName': 'Библиотекарь с длинным именем и фамилией',
          'role': 'librarian',
        },
      ]),
    );
  }
  if (r.path == '/loans') {
    return reply(
      pageJson([
        {
          'id': 1,
          'book': bookJson(),
          'reader': seed.readers.first.toJson(),
          'status': 'active',
          'dueAt': '2026-12-01T12:00:00Z',
        },
      ]),
    );
  }
  if (r.path == '/books/1') {
    return reply(bookJson(title: 'Очень длинное название книги ' * 10));
  }
  if (r.path == '/books') {
    return reply(
      pageJson([bookJson(title: 'Очень длинное название книги ' * 10)]),
    );
  }
  if (r.path == '/publishers/1/options') {
    return reply({
      'hasBooks': true,
      'authorIds': [1],
      'genreIds': [1],
    });
  }
  final parts = r.path.split('/');
  if (parts.length == 3 && int.tryParse(parts.last) != null) {
    final items = seed.sections[parts[1]];
    if (items != null && items.isNotEmpty) return reply(items.first.toJson());
  }
  return referencesReply(r);
}

Future<(AuthNotifier, ApiClient)> signedIn(
  WidgetTester tester,
  String role,
) async {
  SharedPreferences.setMockInitialValues({});
  final auth = AuthNotifier(preferences: await SharedPreferences.getInstance());
  final dio = buildDio(
    baseUrl: 'http://example.test/api',
    tokenProvider: () => auth.token,
    logger: (_) {},
  );
  dio.httpClientAdapter = FakeApiAdapter(screenReply);
  final client = ApiClient(
    dio,
    retryDelays: const [Duration.zero, Duration.zero],
  );
  auth.client = client;
  await tester.runAsync(() => auth.login(role, 'Password1!'));
  return (auth, client);
}

void main() {
  testWidgets('загрузка показывает индикатор до завершения ответа API', (
    tester,
  ) async {
    final gate = Completer<ResponseBody>();
    final client = fakeClient(
      FakeApiAdapter(
        (r) => r.path == '/books' ? gate.future : referencesReply(r),
      ),
    );
    await tester.pumpWidget(
      LibraryApp(initialLocation: '/books', apiClient: client),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Загружаем каталог…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(reply(pageJson([bookJson()])));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Книга API'), findsOneWidget);
  });

  testWidgets(
    'пустой ответ API показывает подсказку вместо таблицы и индикатора',
    (tester) async {
      final client = fakeClient(
        FakeApiAdapter(
          (r) => r.path == '/books' ? reply(pageJson([])) : referencesReply(r),
        ),
      );
      await tester.pumpWidget(
        LibraryApp(initialLocation: '/books', apiClient: client),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.text('Сбросить фильтры'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'после разрыва связи повтор загружает каталог без перезапуска приложения',
    (tester) async {
      var offline = true;
      final adapter = FakeApiAdapter((r) {
        if (r.path == '/books') {
          if (offline) {
            throw DioException(
              requestOptions: r,
              type: DioExceptionType.connectionError,
            );
          }
          return reply(pageJson([bookJson(title: 'Связь восстановлена')]));
        }
        return referencesReply(r);
      });
      await tester.pumpWidget(
        LibraryApp(initialLocation: '/books', apiClient: fakeClient(adapter)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Не удалось загрузить данные'), findsOneWidget);
      expect(find.textContaining('Нет соединения с сервером'), findsOneWidget);
      offline = false;
      await tester.ensureVisible(find.text('Повторить'));
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Связь восстановлена'), findsOneWidget);
      expect(find.text('Не удалось загрузить данные'), findsNothing);
    },
  );

  testWidgets('пустая форма выделяет обязательные поля и не отправляет POST', (
    tester,
  ) async {
    final adapter = FakeApiAdapter(screenReply);
    await tester.pumpWidget(
      LibraryApp(initialLocation: '/books/new', apiClient: fakeClient(adapter)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('save-entity')));
    await tester.tap(find.byKey(const ValueKey('save-entity')));
    await tester.pumpAndSettle();
    expect(find.text('Обязательное поле'), findsWidgets);
    expect(adapter.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets(
    'у читателя нет кнопок записи и административных разделов на телефоне',
    (tester) async {
      viewport(tester, 360);
      final (auth, client) = await signedIn(tester, 'reader');
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
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.byTooltip('Все разделы'));
      await tester.pumpAndSettle();
      expect(find.text('Авторы'), findsOneWidget);
      expect(find.text('Читатели'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );

  testWidgets(
    'вход доступен с клавиатуры: логин, пароль, показ пароля, отправка',
    (tester) async {
      final auth = AuthNotifier();
      await tester.pumpWidget(
        LibraryApp(initialLocation: '/login', apiSession: auth),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-username')),
        'reader',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final password = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('auth-password')),
          matching: find.byType(EditableText),
        ),
      );
      expect(password.focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Заполните поле.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );

  for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
    testWidgets(
      'основные экраны и длинные названия без переполнения при ширине $width',
      (tester) async {
        viewport(tester, width);
        for (final (role, paths) in [
          (
            'admin',
            [
              '/',
              '/books',
              '/authors',
              '/genres',
              '/publishers',
              '/readers',
              '/books/1',
              '/authors/1',
              '/readers/1',
              '/books/new',
              '/readers/new',
              '/admin/users',
              '/admin/stats',
              '/forbidden',
              '/unknown',
            ],
          ),
          ('librarian', ['/loans', '/books/1/issue']),
          ('reader', ['/my-loans']),
        ]) {
          final (auth, client) = await signedIn(tester, role);
          for (final path in paths) {
            await tester.pumpWidget(
              LibraryApp(
                key: ValueKey('$width/$path'),
                initialLocation: path,
                apiClient: client,
                apiSession: auth,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$width px: $role $path',
            );
            expect(
              find.byType(NavigationBar),
              width < 600 ? findsOneWidget : findsNothing,
            );
            if (width >= 600) {
              expect(
                tester
                    .widget<NavigationRail>(find.byType(NavigationRail))
                    .extended,
                width >= 1100,
              );
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          auth.dispose();
        }
        final auth = AuthNotifier();
        for (final path in ['/login', '/register']) {
          await tester.pumpWidget(
            LibraryApp(
              key: ValueKey(path),
              initialLocation: path,
              apiSession: auth,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$width px: $path');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        auth.dispose();
      },
    );
  }

  testWidgets(
    'изменение ширины сохраняет поиск и перестраивает навигацию без перезагрузки',
    (tester) async {
      viewport(tester, 360);
      await tester.pumpWidget(
        const LibraryApp(initialLocation: '/books?search=Война'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const ValueKey('entity-cards')), findsOneWidget);
      for (final width in [768.0, 1280.0, 1920.0, 360.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(find.text('Война и мир'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('catalog-search')))
              .controller!
              .text,
          'Война',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
