import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:library_app/main.dart';
import 'package:library_app/models/author.dart';
import 'package:library_app/models/book.dart';
import 'package:library_app/repositories/library_database.dart';
import 'package:library_app/widgets/entity_actions.dart';
import 'package:library_app/widgets/entity_table.dart';
import 'package:library_app/widgets/pagination_bar.dart';

Future<void> launch(
  WidgetTester tester,
  String location, {
  bool mobile = false,
  LibraryDatabase? database,
}) async {
  tester.view.physicalSize = mobile
      ? const Size(390, 844)
      : const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    LibraryApp(initialLocation: location, database: database),
  );
  await tester.pumpAndSettle();
}

Uri currentUri(WidgetTester tester) => GoRouter.of(
  tester.element(find.byKey(const ValueKey('catalog-search'))),
).routeInformationProvider.value.uri;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Поиск перед окончанием debounce сбрасывает страницу при другом действии',
    (tester) async {
      await launch(tester, '/books');
      await tester.enterText(find.byKey(const ValueKey('catalog-search')), 'а');
      await tester.ensureVisible(find.byTooltip('Следующая страница'));
      await tester.tap(find.byTooltip('Следующая страница'));
      await tester.pumpAndSettle();
      expect(currentUri(tester).queryParameters['page'], '1');
      expect(currentUri(tester).queryParameters['search'], 'а');
    },
  );

  testWidgets(
    'Меню записи связывает удаление, восстановление и физическое удаление',
    (tester) async {
      await launch(tester, '/genres?search=детектив');
      await tapVisible(tester, find.byType(EntityActions));
      await tapVisible(tester, find.text('Удалить', skipOffstage: false).last);
      await tapVisible(tester, find.byKey(const ValueKey('confirm-action')));
      expect(find.text('Всего записей: 0'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('include-deleted')));
      expect(find.text('Удалено'), findsOneWidget);
      await tapVisible(tester, find.byType(EntityActions));
      await tapVisible(tester, find.text('Восстановить'));
      expect(find.text('Удалено'), findsNothing);
      expect(find.text('Всего записей: 1'), findsOneWidget);
      await tapVisible(tester, find.byType(EntityActions));
      await tapVisible(tester, find.text('Удалить навсегда'));
      await tapVisible(tester, find.byKey(const ValueKey('confirm-action')));
      expect(find.text('Всего записей: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Книги и авторы используют одну обобщённую таблицу', (
    tester,
  ) async {
    await launch(tester, '/books');
    expect(find.byType(EntityTable<Book>), findsOneWidget);
    expect(find.text('Всего записей: 20'), findsOneWidget);
    await tapVisible(tester, find.text('Авторы').first);
    expect(find.byType(EntityTable<Author>), findsOneWidget);
    expect(find.text('Всего записей: 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Мобильный список показывает карточки без переполнения', (
    tester,
  ) async {
    await launch(tester, '/books', mobile: true);
    expect(find.byKey(const ValueKey('entity-cards')), findsOneWidget);
    expect(find.byKey(const ValueKey('entity-table')), findsNothing);
  });

  testWidgets(
    'Поиск ждёт 400 мс, обновляет URL и показывает пустой результат',
    (tester) async {
      await launch(tester, '/books?page=2');
      await tester.enterText(
        find.byKey(const ValueKey('catalog-search')),
        'несуществующаякнига',
      );
      await tester.pump(const Duration(milliseconds: 399));
      expect(currentUri(tester).queryParameters['search'], isNull);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(currentUri(tester).queryParameters['page'], '1');
      expect(
        currentUri(tester).queryParameters['search'],
        'несуществующаякнига',
      );
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tapVisible(tester, find.text('Сбросить фильтры'));
      expect(find.text('Всего записей: 20'), findsOneWidget);
    },
  );

  testWidgets('Ссылка восстанавливает фильтры, размер страницы и сортировку', (
    tester,
  ) async {
    await launch(
      tester,
      '/books?genreId=1&publisherId=1&yearFrom=1800&yearTo=1900&sort=year,desc&size=25',
    );
    expect(find.text('Всего записей: 2'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('year-from')))
          .controller!
          .text,
      '1800',
    );
    final table = tester.widget<EntityTable<Book>>(
      find.byType(EntityTable<Book>),
    );
    expect(table.sortField, 'year');
    expect(table.sortAscending, isFalse);
    final pagination = tester.widget<PaginationBar>(find.byType(PaginationBar));
    expect(pagination.size, 25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Пагинация и заголовок сортировки меняют параметры URL', (
    tester,
  ) async {
    await launch(tester, '/books');
    await tapVisible(tester, find.byTooltip('Следующая страница'));
    expect(currentUri(tester).queryParameters['page'], '2');
    await tapVisible(tester, find.text('Год').first);
    expect(currentUri(tester).queryParameters['sort'], 'year,asc');
    expect(currentUri(tester).queryParameters['page'], '1');
    await tapVisible(tester, find.text('Год').first);
    expect(currentUri(tester).queryParameters['sort'], 'year,desc');
  });

  testWidgets('Массовое удаление требует подтверждения и скрывает записи', (
    tester,
  ) async {
    await launch(tester, '/authors');
    await tapVisible(tester, find.byType(Checkbox).at(1));
    expect(find.text('Выбрано: 1'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('delete-selected')));
    await tapVisible(tester, find.text('Отмена'));
    expect(find.text('Всего записей: 10'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('delete-selected')));
    await tapVisible(tester, find.byKey(const ValueKey('confirm-action')));
    expect(find.text('Всего записей: 9'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('include-deleted')));
    expect(find.text('Всего записей: 10'), findsOneWidget);
    expect(find.text('Удалено'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ошибку можно повторить, неверный адрес показывает 404', (
    tester,
  ) async {
    await launch(tester, '/books?__fail=500');
    expect(find.text('Не удалось загрузить данные'), findsOneWidget);
    await tapVisible(tester, find.text('Повторить'));
    expect(find.byType(EntityTable<Book>), findsOneWidget);
    final router = GoRouter.of(
      tester.element(find.byKey(const ValueKey('catalog-search'))),
    );
    router.go('/unknown');
    await tester.pumpAndSettle();
    expect(find.text('Страница не найдена · 404'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Карточка и возврат сохраняют параметры списка', (tester) async {
    await launch(tester, '/books?search=Война&sort=year,desc&size=25');
    await tapVisible(tester, find.text('Война и мир'));
    expect(find.text('Количество страниц'), findsOneWidget);
    await tapVisible(tester, find.text('К списку'));
    expect(currentUri(tester).queryParameters['search'], 'Война');
    expect(currentUri(tester).queryParameters['sort'], 'year,desc');
    expect(find.text('Всего записей: 1'), findsOneWidget);
  });
}
