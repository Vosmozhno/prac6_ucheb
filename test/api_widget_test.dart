import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/main.dart';
import 'package:library_app/models/library_snapshot.dart';
import 'package:library_app/widgets/entity_table.dart';
import 'support/fake_api.dart';

void main() {
  testWidgets('409 выдачи показывается пользователю сообщением сервера', (
    tester,
  ) async {
    final book = bookJson()..['copiesAvailable'] = 0;
    final adapter = FakeApiAdapter((options) {
      if (options.path == '/books/1') return reply(book);
      if (options.path == '/books') return reply(pageJson([book]));
      if (options.path == '/readers') {
        return reply(pageJson([LibrarySnapshot.seed().readers.first.toJson()]));
      }
      if (options.path == '/loans') {
        return reply({'message': 'Нет свободных экземпляров этой книги'}, 409);
      }
      return referencesReply(options);
    });
    await tester.pumpWidget(
      LibraryApp(
        initialLocation: '/books/1/issue',
        apiClient: fakeClient(adapter),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Читатель №1').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Оформить выдачу'));
    await tester.tap(find.text('Оформить выдачу'));
    await tester.pumpAndSettle();
    expect(find.text('Нет свободных экземпляров этой книги'), findsOneWidget);
    expect(
      adapter.requests
          .where((r) => r.method == 'POST' && r.path == '/loans')
          .length,
      1,
    );
  });
  testWidgets(
    'Приложение API показывает серверные данные без LibraryDatabase',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final adapter = FakeApiAdapter((options) {
        if (options.path == '/books') {
          return reply(pageJson([bookJson(title: 'Книга только с сервера')]));
        }
        return referencesReply(options);
      });
      await tester.pumpWidget(
        LibraryApp(initialLocation: '/books', apiClient: fakeClient(adapter)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Книга только с сервера'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is EntityTable),
        findsOneWidget,
      );
      expect(adapter.requests.where((r) => r.path == '/books').length, 1);
    },
  );

  testWidgets('422 API показывается под полем ISBN в существующей форме', (
    tester,
  ) async {
    final adapter = FakeApiAdapter((options) {
      if (options.path == '/books/1') return reply(bookJson());
      if (options.path == '/publishers/1/options') {
        return reply({
          'hasBooks': true,
          'authorIds': [1],
          'genreIds': [1],
        });
      }
      if (options.path == '/books' && options.method == 'POST') {
        return reply({
          'message': 'Ошибка валидации',
          'errors': {'isbn': 'Сервер: такой ISBN уже существует'},
        }, 422);
      }
      if (options.path == '/books') return reply(pageJson([bookJson()]));
      return referencesReply(options);
    });
    await tester.pumpWidget(
      LibraryApp(initialLocation: '/books/new', apiClient: fakeClient(adapter)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('form-title')),
      'Книга API',
    );
    await tester.enterText(
      find.byKey(const ValueKey('form-isbn')),
      '9780000000001',
    );
    await tester.enterText(find.byKey(const ValueKey('form-pages')), '200');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('АСТ').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('choice-authorIds-1')),
    );
    await tester.tap(find.byKey(const ValueKey('choice-authorIds-1')));
    await tester.ensureVisible(find.byKey(const ValueKey('choice-genreIds-1')));
    await tester.tap(find.byKey(const ValueKey('choice-genreIds-1')));
    await tester.ensureVisible(find.byKey(const ValueKey('save-entity')));
    await tester.tap(find.byKey(const ValueKey('save-entity')));
    await tester.pumpAndSettle();
    expect(find.text('Сервер: такой ISBN уже существует'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'POST').length, 1);
  });
}
