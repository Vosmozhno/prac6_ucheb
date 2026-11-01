import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/models/genre.dart';
import 'package:library_app/models/publisher.dart';
import 'package:library_app/models/reader.dart';
import 'package:library_app/screens/entity_form_screen.dart';
import 'package:library_app/widgets/entity_actions.dart';
import 'package:library_app/widgets/entity_table.dart';
import 'widget_test.dart' show launch, tapVisible;

Future<void> fill(WidgetTester tester, String key, String value) =>
    tester.enterText(find.byKey(ValueKey('form-$key')), value);

Future<void> save(WidgetTester tester) =>
    tapVisible(tester, find.byKey(const ValueKey('save-entity')));

void main() {
  testWidgets('Пустая форма книги показывает ошибки под несколькими полями', (
    tester,
  ) async {
    await launch(tester, '/books/new');
    await save(tester);
    expect(find.text('Обязательное поле'), findsNWidgets(3));
    expect(find.text('Выберите действующее издательство'), findsOneWidget);
    expect(find.text('Выберите хотя бы одного автора'), findsOneWidget);
    expect(find.text('Выберите хотя бы один жанр'), findsOneWidget);
    expect(find.byType(EntityFormScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Дубликат ISBN показывается в поле книги', (tester) async {
    await launch(tester, '/books/new');
    await fill(tester, 'isbn', '9785171183664');
    await save(tester);
    expect(find.text('Книга с таким ISBN уже существует'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Книга создаётся со связями, при редактировании поля заполнены', (
    tester,
  ) async {
    await launch(tester, '/books/new');
    await fill(tester, 'title', 'Проверка новой книги');
    await fill(tester, 'isbn', '9780000000018');
    await fill(tester, 'pages', '321');
    await fill(tester, 'year', '2020');
    await fill(tester, 'copiesTotal', '3');
    await tapVisible(tester, find.byType(DropdownButtonFormField<int>));
    await tapVisible(tester, find.text('Азбука').last);
    expect(find.byKey(const ValueKey('choice-authorIds-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('choice-authorIds-7')), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('choice-authorIds-2')));
    await tapVisible(tester, find.byKey(const ValueKey('choice-genreIds-1')));
    await save(tester);
    expect(find.byType(EntityFormScreen), findsNothing);
    expect(find.text('Проверка новой книги'), findsOneWidget);
    expect(find.text('Достоевский Ф. М.'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('edit-entity')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('form-title')))
          .controller!
          .text,
      'Проверка новой книги',
    );
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('choice-authorIds-2')))
          .selected,
      isTrue,
    );
    await fill(tester, 'title', 'Книга после редактирования');
    await save(tester);
    expect(find.text('Книга после редактирования'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  final examples = <String, Map<String, String>>{
    'authors': {
      'fullName': 'Учебный автор',
      'birthYear': '1980',
      'country': 'Россия',
    },
    'genres': {'name': 'Учебный жанр', 'description': 'Описание жанра'},
    'publishers': {
      'name': 'Учебное издательство',
      'city': 'Казань',
      'foundedYear': '2020',
    },
    'readers': {
      'fullName': 'Учебный читатель',
      'email': 'new-reader@example.test',
      'phone': '+7 900 123-45-67',
    },
  };
  for (final entry in examples.entries) {
    testWidgets('Общая форма создаёт и редактирует раздел ${entry.key}', (
      tester,
    ) async {
      await launch(tester, '/${entry.key}/new');
      for (final field in entry.value.entries) {
        await fill(tester, field.key, field.value);
      }
      if (entry.key == 'readers') {
        expect(find.text('Читательский билет'), findsOneWidget);
      }
      await save(tester);
      expect(find.byType(EntityFormScreen), findsNothing);
      final nameKey = entry.value.containsKey('name') ? 'name' : 'fullName';
      final original = entry.value[nameKey]!;
      expect(find.text(original), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('edit-entity')));
      expect(
        tester
            .widget<TextFormField>(find.byKey(ValueKey('form-$nameKey')))
            .controller!
            .text,
        original,
      );
      await fill(tester, nameKey, '$original изменён');
      await save(tester);
      expect(find.text('$original изменён'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Отказ удаления издательства оставляет список и показывает число книг',
    (tester) async {
      await launch(tester, '/publishers?search=Эксмо');
      await tapVisible(tester, find.byType(EntityActions));
      await tapVisible(tester, find.text('Удалить').last);
      await tapVisible(tester, find.byKey(const ValueKey('confirm-action')));
      expect(find.text('Действие не выполнено'), findsOneWidget);
      expect(find.textContaining('связанных книг — 4'), findsOneWidget);
      expect(find.text('Всего записей: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Навигация предупреждает об изменениях и позволяет остаться', (
    tester,
  ) async {
    await launch(tester, '/authors/new');
    await fill(tester, 'fullName', 'Не сохранён');
    await tapVisible(tester, find.text('Книги').first);
    expect(find.text('Есть несохранённые изменения'), findsOneWidget);
    await tapVisible(tester, find.text('Остаться'));
    expect(find.byType(EntityFormScreen), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('form-fullName')))
          .controller!
          .text,
      'Не сохранён',
    );
    await tapVisible(tester, find.text('Книги').first);
    await tapVisible(tester, find.byKey(const ValueKey('discard-changes')));
    expect(find.byType(EntityFormScreen), findsNothing);
    expect(find.text('Каталог книг'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PopScope обрабатывает возврат из изменённой формы', (
    tester,
  ) async {
    await launch(tester, '/genres/new');
    await fill(tester, 'name', 'Не сохранённый жанр');
    final back = tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Есть несохранённые изменения'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('discard-changes')));
    await back;
    await tester.pumpAndSettle();
    expect(find.byType(EntityFormScreen), findsNothing);
    expect(find.byKey(const ValueKey('catalog-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Форма книги помещается в мобильное окно', (tester) async {
    await launch(tester, '/books/new', mobile: true);
    await save(tester);
    expect(find.text('Выберите хотя бы один жанр'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Новые разделы используют общую таблицу', (tester) async {
    await launch(tester, '/genres');
    expect(find.byType(EntityTable<Genre>), findsOneWidget);
    await tapVisible(tester, find.text('Издательства').first);
    expect(find.byType(EntityTable<Publisher>), findsOneWidget);
    await tapVisible(tester, find.text('Читатели').first);
    expect(find.byType(EntityTable<Reader>), findsOneWidget);
    expect(find.text('Всего записей: 12'), findsOneWidget);
    await tapVisible(tester, find.byTooltip('Следующая страница'));
    expect(find.text('2 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Дубликат почты и неверные даты билета видны в своих полях', (
    tester,
  ) async {
    await launch(tester, '/readers/new');
    await fill(tester, 'email', 'READER1@example.test');
    await fill(tester, 'card.issuedAt', '2026-02-31');
    await fill(tester, 'card.expiresAt', 'bad date');
    await save(tester);
    expect(find.text('Читатель с такой почтой уже существует'), findsOneWidget);
    expect(find.text('Дата в формате ГГГГ-ММ-ДД'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
