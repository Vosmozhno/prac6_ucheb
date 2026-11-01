import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/models/book_query.dart';
import 'package:library_app/models/list_query.dart';
import 'package:library_app/repositories/in_memory_author_repository.dart';
import 'package:library_app/repositories/in_memory_book_repository.dart';

void main() {
  test('Поиск комбинируется с фильтрами книг', () async {
    final repository = InMemoryBookRepository();

    final result = await repository.find(
      const BookQuery(
        search: 'ВОЙНА',
        genreId: 1,
        publisherId: 1,
        yearFrom: 1800,
        yearTo: 1900,
      ),
    );

    expect(result.total, 1);
    expect(result.items.single.id, 1);
  });

  test('После удаления последней страницы номер исправляется', () async {
    final repository = InMemoryBookRepository();

    final secondPage = await repository.find(const BookQuery(page: 2));

    expect(secondPage.total, 20);
    expect(secondPage.items.length, 10);

    await repository.deleteMany(
      secondPage.items.map((book) => book.id).toList(),
    );

    final result = await repository.find(const BookQuery(page: 2));

    expect(result.page, 1);
    expect(result.totalPages, 1);
    expect(result.total, 10);
    expect(result.items.length, 10);
  });

  test(
    'Множественное удаление, восстановление и физическое удаление',
    () async {
      final repository = InMemoryBookRepository();

      final count = await repository.deleteMany([1, 1, 2, 999]);

      expect(count, 2);
      expect(await repository.findById(1), isNull);

      final withDeleted = await repository.find(
        const BookQuery(includeDeleted: true),
      );
      expect(withDeleted.total, 20);

      await repository.restore(1);
      expect(await repository.findById(1), isNotNull);

      await repository.hardDelete(1);
      expect(await repository.findById(1), isNull);

      await expectLater(repository.restore(1), throwsStateError);
    },
  );

  test('Параметры восстанавливаются из URL, фильтр сбрасывается', () {
    const query = BookQuery(
      search: 'Война и мир',
      genreId: 1,
      publisherId: 1,
      yearFrom: 1800,
      yearTo: 2000,
      sortField: 'year',
      sortAscending: false,
      page: 2,
      size: 25,
      includeDeleted: true,
    );

    final uri = Uri.parse(query.toUri('/books').toString());
    final restored = BookQuery.fromParameters(uri.queryParameters);

    expect(restored.toQueryParameters(), query.toQueryParameters());

    final cleared = query.copyWith(genreId: null);

    expect(cleared.genreId, isNull);
    expect(cleared.publisherId, 1);
    expect(cleared.page, 1);
  });

  test('Автор находится по стране', () async {
    final repository = InMemoryAuthorRepository();

    final result = await repository.find(const ListQuery(search: 'германия'));

    expect(result.total, 1);
    expect(result.items.single.fullName, 'Ремарк Э. М.');
  });
}
