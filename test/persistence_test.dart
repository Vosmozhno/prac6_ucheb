import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/models/author.dart';
import 'package:library_app/models/book.dart';
import 'package:library_app/models/book_query.dart';
import 'package:library_app/models/entity_draft.dart';
import 'package:library_app/models/genre.dart';
import 'package:library_app/models/library_snapshot.dart';
import 'package:library_app/models/list_query.dart';
import 'package:library_app/models/publisher.dart';
import 'package:library_app/models/reader.dart';
import 'package:library_app/repositories/catalog_exception.dart';
import 'package:library_app/repositories/library_database.dart';
import 'package:library_app/repositories/library_repositories.dart';
import 'package:library_app/state/catalog_references.dart';
import 'package:library_app/state/entity_form_notifier.dart';
import 'package:library_app/state/reference_list_notifier.dart';
import 'package:library_app/validation/entity_validation.dart';
import 'package:library_app/validation/validators.dart';

class FailingStorage extends MemoryCatalogStorage {
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('Storage unavailable');
    await super.write(key, value);
  }
}

void main() {
  test('Все модели выдерживают отсутствующие, null и неверные типы полей', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'id': null},
      {'id': 'bad', 'name': [], 'card': 7},
    ]) {
      expect(() => Book.fromJson(data), returnsNormally);
      expect(() => Author.fromJson(data), returnsNormally);
      expect(() => Genre.fromJson(data), returnsNormally);
      expect(() => Publisher.fromJson(data), returnsNormally);
      expect(() => Reader.fromJson(data), returnsNormally);
      expect(() => LibraryCard.fromJson(data), returnsNormally);
    }
    final book = Book.fromJson({
      'id': '7',
      'title': 'Книга',
      'publisher': {'id': 3},
      'authors': [
        {'id': 1},
        {'id': '2'},
        null,
      ],
      'genres': [
        {'id': 6},
      ],
      'deletedAt': 'не дата',
      'pages': 300.0,
    });
    expect(book.id, 7);
    expect(book.publisherId, 3);
    expect(book.authorIds, [1, 2]);
    expect(book.pages, 300);
    expect(book.deletedAt, isNull);
    expect(() => book.authorIds.add(9), throwsUnsupportedError);
  });

  test('Сериализация сохраняет все пять сущностей и вложенный билет', () {
    final source = LibrarySnapshot.seed();
    final restored = LibrarySnapshot.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), source.toJson());
    expect(
      restored.readers.first.card.toJson(),
      source.readers.first.card.toJson(),
    );
  });

  test(
    'Создание и редактирование переживают повторное открытие хранилища',
    () async {
      final storage = MemoryCatalogStorage();
      final db = await LibraryDatabase.open(storage);
      final repos = LibraryRepositories(db);
      final author = await repos.authors.create(
        const Author(
          id: 0,
          fullName: 'Новый автор',
          birthYear: 1990,
          country: 'Россия',
        ),
      );
      final genre = await repos.genres.create(
        const Genre(id: 0, name: 'Новый жанр'),
      );
      final publisher = await repos.publishers.create(
        const Publisher(
          id: 0,
          name: 'Новое издательство',
          city: 'Казань',
          foundedYear: 2020,
        ),
      );
      final source = db.snapshot.books.first.copyWith(
        id: 0,
        title: 'Новая книга',
        isbn: '9780000000001',
        publisherId: publisher.id,
        authorIds: [author.id],
        genreIds: [genre.id],
      );
      final book = await repos.books.create(source);
      final reader = await repos.readers.create(
        Reader(
          id: 0,
          fullName: 'Новый читатель',
          email: 'new@example.test',
          phone: '+7 900 123 4567',
          card: LibraryCard(
            id: 0,
            number: 'NEW-001',
            issuedAt: DateTime.utc(2025),
            expiresAt: DateTime.utc(2027),
          ),
        ),
      );
      await repos.books.update(book.copyWith(title: 'Изменённое название'));
      final second = await LibraryDatabase.open(storage);
      expect(second.snapshot.books.last.title, 'Изменённое название');
      expect(second.snapshot.books.last.publisherId, publisher.id);
      expect(second.snapshot.books.last.authorIds, [author.id]);
      expect(second.snapshot.books.last.genreIds, [genre.id]);
      expect(second.snapshot.readers.last.card.id, reader.id);
      expect(second.snapshot.readers.last.card.number, 'NEW-001');
      expect(second.snapshot.authors.last.fullName, author.fullName);
      db.dispose();
      second.dispose();
    },
  );

  test(
    'Уникальность ISBN не зависит от дефисов и учитывает удалённые записи',
    () async {
      final db = LibraryDatabase.memory();
      final repos = LibraryRepositories(db);
      final book = db.snapshot.books.first;
      final duplicate = book.copyWith(
        id: 0,
        isbn: book.isbn.replaceAll('-', ''),
      );
      await expectLater(
        repos.books.create(duplicate),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.fields['isbn'],
            'ошибка ISBN',
            isNotNull,
          ),
        ),
      );
      await repos.books.softDelete(book.id);
      await expectLater(
        repos.books.create(duplicate),
        throwsA(isA<CatalogException>()),
      );
      await repos.books.restore(book.id);
      expect(
        await repos.books.update(book.copyWith(title: 'Новое название')),
        isA<Book>(),
      );
      db.dispose();
    },
  );

  test('Почта читателя уникальна без учёта регистра', () async {
    final db = LibraryDatabase.memory();
    final repos = LibraryRepositories(db);
    final source = db.snapshot.readers.first;
    final duplicate = source.copyWith(
      id: 0,
      email: source.email.toUpperCase(),
      card: source.card.copyWith(id: 0, number: 'OTHER-001'),
    );
    await expectLater(
      repos.readers.create(duplicate),
      throwsA(
        isA<CatalogException>().having(
          (e) => e.fields['email'],
          'ошибка почты',
          isNotNull,
        ),
      ),
    );
    db.dispose();
  });

  test(
    'Удаление издательства сообщает число книг, пакетное удаление атомарно',
    () async {
      final storage = MemoryCatalogStorage();
      final db = await LibraryDatabase.open(storage);
      final repos = LibraryRepositories(db);
      final unused = await repos.publishers.create(
        const Publisher(
          id: 0,
          name: 'Без книг',
          city: 'Москва',
          foundedYear: 2020,
        ),
      );
      final before = storage.values[LibraryDatabase.storageKey];
      await expectLater(
        repos.publishers.deleteMany([unused.id, 2]),
        throwsA(
          isA<CatalogException>().having(
            (e) => e.message,
            'число книг',
            contains('— 4'),
          ),
        ),
      );
      expect((await repos.publishers.findById(unused.id)), isNotNull);
      expect(storage.values[LibraryDatabase.storageKey], before);
      await repos.books.softDelete(13);
      await expectLater(
        repos.publishers.hardDelete(2),
        throwsA(isA<CatalogException>()),
      );
      db.dispose();
    },
  );

  test(
    'Ошибка записи не меняет данные в памяти и не расходует идентификатор',
    () async {
      final storage = FailingStorage();
      final db = await LibraryDatabase.open(storage);
      final repos = LibraryRepositories(db);
      storage.fail = true;
      await expectLater(
        repos.genres.create(const Genre(id: 0, name: 'Новый жанр')),
        throwsStateError,
      );
      expect(db.snapshot.genres.length, 6);
      expect(db.revision, 0);
      storage.fail = false;
      final saved = await repos.genres.create(
        const Genre(id: 0, name: 'Новый жанр'),
      );
      expect(saved.id, 7);
      db.dispose();
    },
  );

  test('Параллельные сохранения не теряют записи', () async {
    final storage = MemoryCatalogStorage();
    final db = await LibraryDatabase.open(storage);
    final repos = LibraryRepositories(db);
    final genres = await Future.wait([
      repos.genres.create(const Genre(id: 0, name: 'Первый жанр')),
      repos.genres.create(const Genre(id: 0, name: 'Второй жанр')),
    ]);
    expect(genres.map((g) => g.id).toSet(), {7, 8});
    await Future.wait([
      repos.publishers.create(
        const Publisher(
          id: 0,
          name: 'Новое издательство',
          city: 'Казань',
          foundedYear: 2020,
        ),
      ),
      repos.authors.create(
        const Author(
          id: 0,
          fullName: 'Новый автор',
          birthYear: 1980,
          country: 'Россия',
        ),
      ),
    ]);
    final reloaded = await LibraryDatabase.open(storage);
    expect(reloaded.snapshot.genres.length, 8);
    expect(reloaded.snapshot.publishers.length, 5);
    expect(reloaded.snapshot.authors.length, 11);
    db.dispose();
    reloaded.dispose();
  });

  test(
    'Повреждение и смена версии сохраняют резервную копию и показывают сообщение',
    () async {
      for (final raw in ['{bad json', '{"schemaVersion":1}']) {
        final storage = MemoryCatalogStorage({LibraryDatabase.storageKey: raw});
        final db = await LibraryDatabase.open(storage);
        expect(db.notice, isNotEmpty);
        expect(db.snapshot.books.length, 20);
        expect(
          storage.values.entries.any(
            (e) => e.key.contains('_backup_') && e.value == raw,
          ),
          isTrue,
        );
        db.dispose();
      }
      final storage = MemoryCatalogStorage({
        LibraryDatabase.previousKey: 'old snapshot',
      });
      final db = await LibraryDatabase.open(storage);
      expect(db.notice, contains('версии 2'));
      expect(storage.values[LibraryDatabase.previousKey], 'old snapshot');
      db.dispose();
    },
  );

  test('Пустой сохранённый каталог не заменяется начальными данными', () async {
    final snapshot = LibrarySnapshot({
      'books': [],
      'authors': [],
      'genres': [],
      'publishers': [],
      'readers': [],
    });
    final storage = MemoryCatalogStorage({
      LibraryDatabase.storageKey: jsonEncode({
        'schemaVersion': 2,
        ...snapshot.toJson(),
      }),
    });
    final db = await LibraryDatabase.open(storage);
    expect(db.snapshot.books, isEmpty);
    expect(db.notice, isNull);
    db.dispose();
  });

  test(
    'Повторяющиеся билеты в хранилище восстанавливаются из начального набора',
    () async {
      final snapshot = LibrarySnapshot.seed();
      final broken = snapshot.replace('readers', [
        snapshot.readers[0],
        snapshot.readers[1].copyWith(card: snapshot.readers[0].card),
      ]);
      final raw = jsonEncode({'schemaVersion': 2, ...broken.toJson()});
      final storage = MemoryCatalogStorage({LibraryDatabase.storageKey: raw});
      final database = await LibraryDatabase.open(storage);
      expect(database.notice, isNotEmpty);
      expect(database.snapshot.readers.length, 12);
      expect(storage.values.values, contains(raw));
      database.dispose();
    },
  );

  test(
    'Фильтры, сортировка и пагинация работают у новых справочников',
    () async {
      final db = LibraryDatabase.memory();
      final repos = LibraryRepositories(db);
      expect(
        (await repos.genres.find(
          const ListQuery(filter: 'unused', sortField: 'name'),
        )).total,
        1,
      );
      expect(
        (await repos.publishers.find(
          const ListQuery(filter: 'Москва', sortField: 'foundedYear'),
        )).total,
        2,
      );
      final readers = await repos.readers.find(const ListQuery(page: 2));
      expect(readers.total, 12);
      expect(readers.items.length, 2);
      expect(
        (await repos.readers.find(const ListQuery(filter: 'expired'))).total,
        3,
      );
      await repos.readers.softDelete(4);
      expect(
        (await repos.readers.find(const ListQuery(filter: 'expired'))).total,
        2,
      );
      expect(
        (await repos.readers.find(
          const ListQuery(filter: 'expired', includeDeleted: true),
        )).total,
        3,
      );
      await repos.readers.restore(4);
      await repos.readers.hardDelete(4);
      expect(
        (await repos.readers.find(const ListQuery(includeDeleted: true))).total,
        11,
      );
      db.dispose();
    },
  );

  test('Список с прежним URL обновляется после сохранения формы', () async {
    final db = LibraryDatabase.memory();
    final repos = LibraryRepositories(db);
    final state = GenreListNotifier(repos.genres);
    await state.applyQuery(const ListQuery(sortField: 'name'));
    expect(state.result.total, 6);
    await repos.genres.create(const Genre(id: 0, name: 'Добавленный жанр'));
    await state.applyQuery(const ListQuery(sortField: 'name'));
    expect(state.result.total, 7);
    state.dispose();
    db.dispose();
  });

  test(
    'Каскадный выбор очищает неподходящих авторов и оставляет общие жанры',
    () async {
      final db = LibraryDatabase.memory();
      final repos = LibraryRepositories(db);
      final refs = CatalogReferences(database: db);
      final state = EntityFormNotifier(repos, refs, 'books', null);
      await state.load();
      state.setValue('publisherId', 1);
      state.setValue('authorIds', [1, 8]);
      state.setValue('genreIds', [1, 3]);
      state.setValue('publisherId', 3);
      expect(refs.availableAuthors(3).keys.toSet(), {2});
      expect(state.values['authorIds'], isEmpty);
      expect(state.values['genreIds'], [1, 3]);
      state.dispose();
      refs.dispose();
      db.dispose();
    },
  );

  test(
    'Редактирование распознаёт исходное числовое значение и сбрасывает dirty после сохранения',
    () async {
      final db = LibraryDatabase.memory();
      final refs = CatalogReferences(database: db);
      final state = EntityFormNotifier(
        LibraryRepositories(db),
        refs,
        'books',
        1,
      );
      await state.load();
      expect(state.dirty, isFalse);
      state.setValue('year', '1869');
      expect(state.dirty, isFalse);
      state.setValue('title', 'Обновлённая книга');
      expect(state.dirty, isTrue);
      expect(await state.save(), isNotNull);
      expect(state.dirty, isFalse);
      state.dispose();
      refs.dispose();
      db.dispose();
    },
  );

  test(
    'Валидация ловит неверные даты, диапазоны и несколько ошибок одновременно',
    () {
      expect(Validators.parseDate('2026-02-31'), isNull);
      expect(Validators.parseDate('2024-02-29'), isNotNull);
      expect(Validators.integer('1.5'), isNotNull);
      expect(Validators.email('wrong'), isNotNull);
      expect(Validators.phone('abc'), isNotNull);
      final data = LibrarySnapshot.seed();
      final errors = EntityValidation.validate('readers', {
        'fullName': '',
        'email': 'bad',
        'phone': '1',
        'card.number': '!',
        'card.issuedAt': '2026-02-31',
        'card.expiresAt': '',
      }, data);
      expect(
        errors.keys,
        containsAll([
          'fullName',
          'email',
          'phone',
          'card.number',
          'card.issuedAt',
          'card.expiresAt',
        ]),
      );
      final own = entityDraft(data.books.first);
      expect(EntityValidation.validate('books', own, data, id: 1), isEmpty);
      expect(BookQuery.fromParameters({'page': '-2', 'size': '0'}).page, 1);
    },
  );
}
