import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/data/seed_data.dart';
import 'package:library_app/models/book.dart';
import 'package:library_app/models/book_query.dart';
import 'package:library_app/models/page_result.dart';
import 'package:library_app/repositories/in_memory_book_repository.dart';
import 'package:library_app/state/book_list_notifier.dart';
import 'package:library_app/state/entity_list_notifier.dart';

class ControlledRepository extends InMemoryBookRepository {
  final pending = <Completer<PageResult<Book>>>[];
  @override
  Future<PageResult<Book>> find(BookQuery query) {
    final completer = Completer<PageResult<Book>>();
    pending.add(completer);
    return completer.future;
  }
}

PageResult<Book> result(Book book) =>
    PageResult(items: [book], page: 1, size: 10, total: 1);

void main() {
  test('Поздний ответ старого поиска не заменяет новый результат', () async {
    final repository = ControlledRepository();
    final state = BookListNotifier(repository);
    addTearDown(state.dispose);
    final old = state.applyQuery(const BookQuery(search: 'старый'));
    final latest = state.applyQuery(const BookQuery(search: 'новый'));
    repository.pending[1].complete(result(seedBooks[1]));
    await latest;
    repository.pending[0].complete(result(seedBooks[0]));
    await old;
    expect(state.query.search, 'новый');
    expect(state.result.items.single.id, seedBooks[1].id);
    expect(state.status, LoadStatus.success);
  });

  test('Ответ после dispose не уведомляет уничтоженное состояние', () async {
    final repository = ControlledRepository();
    final state = BookListNotifier(repository);
    final loading = state.applyQuery(const BookQuery());
    state.dispose();
    repository.pending.single.complete(result(seedBooks.first));
    await loading;
  });

  test(
    'Выделение ограничено текущей страницей и сбрасывается с запросом',
    () async {
      final state = BookListNotifier(InMemoryBookRepository());
      addTearDown(state.dispose);
      await state.applyQuery(const BookQuery());
      state.selectAll(true);
      expect(state.selected.length, 10);
      state.toggleSelection(999);
      expect(state.selected.length, 10);
      await state.applyQuery(const BookQuery(page: 2));
      expect(state.selected, isEmpty);
      state.selectAll(true);
      await state.deleteIds(state.selected.toList());
      expect(state.result.total, 10);
      expect(state.query.page, 1);
      expect(state.selected, isEmpty);
    },
  );

  test('Ошибка загрузки представлена отдельным состоянием', () async {
    final state = BookListNotifier(InMemoryBookRepository());
    addTearDown(state.dispose);
    await state.applyQuery(const BookQuery(), simulateError: true);
    expect(state.status, LoadStatus.error);
    expect(state.error, isNotEmpty);
    await state.applyQuery(const BookQuery());
    expect(state.status, LoadStatus.success);
    expect(state.result.total, 20);
  });
}
