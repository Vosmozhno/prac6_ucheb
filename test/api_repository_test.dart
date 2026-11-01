import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_app/core/api_exceptions.dart';
import 'package:library_app/models/book_query.dart';
import 'package:library_app/models/genre.dart';
import 'package:library_app/models/library_snapshot.dart';
import 'package:library_app/models/list_query.dart';
import 'package:library_app/models/reader.dart';
import 'package:library_app/repositories/api_entity_repository.dart';
import 'package:library_app/repositories/api_reference_cache.dart';
import 'package:library_app/repositories/api_loan_repository.dart';
import 'package:library_app/repositories/library_repositories.dart';
import 'package:library_app/state/catalog_references.dart';
import 'package:library_app/state/entity_form_notifier.dart';
import 'package:library_app/state/book_list_notifier.dart';
import 'support/fake_api.dart';

void main() {
  test('Поиск читателя для выдачи также отменяет предыдущий запрос', () async {
    final started = Completer<void>();
    final oldReply = Completer<ResponseBody>();
    final reader = LibrarySnapshot.seed().readers.first;
    final adapter = FakeApiAdapter((options) {
      if (options.queryParameters['search'] == 'старый') {
        started.complete();
        return oldReply.future;
      }
      return reply(pageJson([reader.toJson()]));
    });
    final repository = ApiLoanRepository(fakeClient(adapter), ApiRevision());
    final old = repository.readers('старый');
    final cancelled = expectLater(
      old,
      throwsA(isA<RequestCancelledException>()),
    );
    await started.future;
    expect((await repository.readers('новый')).single.id, reader.id);
    await cancelled;
    expect(adapter.requests.first.cancelToken!.isCancelled, isTrue);
    oldReply.complete(reply(pageJson([])));
  });
  test(
    'Reader отправляется и восстанавливается вместе с полями билета',
    () async {
      final reader = LibrarySnapshot.seed().readers.first;
      final adapter = FakeApiAdapter((_) => reply(reader.toJson(), 201));
      final repository = ApiEntityRepository<Reader, ListQuery>(
        fakeClient(adapter),
        'readers',
        Reader.fromJson,
        changes: ApiRevision(),
      );
      final saved = await repository.create(reader);
      final sentCard = (adapter.requests.single.data as Map)['card'] as Map;
      expect(sentCard['number'], reader.card.number);
      expect(sentCard['issuedAt'], reader.card.toJson()['issuedAt']);
      expect(sentCard, isNot(contains('id')));
      expect(saved.card.number, reader.card.number);
      expect(saved.card.expiresAt, reader.card.expiresAt);
    },
  );
  test('GET передаёт отбор на сервер и читает развёрнутые связи', () async {
    final adapter = FakeApiAdapter(
      (_) => reply(pageJson([bookJson()], page: 2, total: 20)),
    );
    final client = fakeClient(adapter, token: 'test-token');
    final repository = ApiBookRepository(client, changes: ApiRevision());
    final result = await repository.find(
      const BookQuery(
        search: 'война',
        genreId: 1,
        publisherId: 1,
        yearFrom: 1800,
        yearTo: 1900,
        sortField: 'year',
        sortAscending: false,
        page: 2,
        size: 10,
        includeDeleted: true,
        debugDelay: 1500,
        debugFail: 500,
      ),
    );
    final request = adapter.requests.single;
    expect(request.uri.path, '/api/books');
    expect(request.queryParameters, {
      'search': 'война',
      'genreId': '1',
      'publisherId': '1',
      'yearFrom': '1800',
      'yearTo': '1900',
      'sort': 'year,desc',
      'page': '2',
      'size': '10',
      'includeDeleted': 'true',
      '__delay': '1500',
      '__fail': '500',
    });
    expect(request.headers['Authorization'], 'Bearer test-token');
    expect(result.items.single.publisherId, 1);
    expect(result.items.single.authorIds, [1]);
    expect(result.items.single.genreIds, [1]);
    expect(result.page, 2);
    expect(result.total, 20);
  });

  test(
    'Каждая страница запрашивается отдельно, каталог не фильтруется локально',
    () async {
      final adapter = FakeApiAdapter((options) {
        final page = int.parse(options.queryParameters['page'].toString());
        return reply(pageJson([bookJson(id: page)], page: page, total: 20));
      });
      final repository = ApiBookRepository(
        fakeClient(adapter),
        changes: ApiRevision(),
      );
      expect((await repository.find(const BookQuery())).items.single.id, 1);
      expect(
        (await repository.find(const BookQuery(page: 2))).items.single.id,
        2,
      );
      expect(adapter.requests.length, 2);
    },
  );

  test('422 остаётся ValidationException с ошибкой поля ISBN', () async {
    final adapter = FakeApiAdapter(
      (_) => reply({
        'message': 'Ошибка валидации',
        'errors': {'isbn': 'Этот ISBN уже существует'},
      }, 422),
    );
    final repository = ApiBookRepository(
      fakeClient(adapter),
      changes: ApiRevision(),
    );
    await expectLater(
      repository.create(LibrarySnapshot.seed().books.first),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors['isbn'],
          'поле ISBN',
          'Этот ISBN уже существует',
        ),
      ),
    );
    expect(adapter.requests.length, 1);
  });

  test('409 преобразуется в понятный конфликт и не повторяется', () async {
    final adapter = FakeApiAdapter(
      (_) => reply({'message': 'Нет свободных экземпляров'}, 409),
    );
    final repositories = LibraryRepositories.remote(
      fakeClient(adapter),
      ApiReferenceCache(fakeClient(adapter)),
    );
    await expectLater(
      repositories.loans!.issue(bookId: 1, readerId: 1, days: 14),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.message,
          'сообщение',
          'Нет свободных экземпляров',
        ),
      ),
    );
    expect(adapter.requests.length, 1);
  });

  test('Недоступный сервер: не более трёх попыток чтения', () async {
    final adapter = FakeApiAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );
    final repository = ApiBookRepository(
      fakeClient(adapter),
      changes: ApiRevision(),
    );
    await expectLater(
      repository.find(const BookQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests.length, 3);
  });

  test('POST с сетевым сбоем отправляется только один раз', () async {
    final adapter = FakeApiAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    final repository = ApiBookRepository(
      fakeClient(adapter),
      changes: ApiRevision(),
    );
    await expectLater(
      repository.create(LibrarySnapshot.seed().books.first),
      throwsA(isA<NetworkException>()),
    );
    expect(adapter.requests.length, 1);
  });

  test(
    'Временный сбой GET исправляется повтором, 500 не повторяется',
    () async {
      var calls = 0;
      final adapter = FakeApiAdapter((options) {
        if (++calls < 3) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return reply(pageJson([bookJson()]));
      });
      final repository = ApiBookRepository(
        fakeClient(adapter),
        changes: ApiRevision(),
      );
      expect((await repository.find(const BookQuery())).items.length, 1);
      expect(adapter.requests.length, 3);
      final failAdapter = FakeApiAdapter(
        (_) => reply({'message': 'Учебная ошибка'}, 500),
      );
      await expectLater(
        ApiBookRepository(
          fakeClient(failAdapter),
          changes: ApiRevision(),
        ).find(const BookQuery()),
        throwsA(isA<ServerException>()),
      );
      expect(failAdapter.requests.length, 1);
    },
  );

  test(
    'Устаревший GET отменяется CancelToken и не заменяет свежий ответ',
    () async {
      final started = Completer<void>();
      final oldResponse = Completer<ResponseBody>();
      final adapter = FakeApiAdapter((options) {
        if (options.queryParameters['search'] == 'во') {
          started.complete();
          return oldResponse.future;
        }
        return reply(pageJson([bookJson(title: 'Война и мир')]));
      });
      final repository = ApiBookRepository(
        fakeClient(adapter),
        changes: ApiRevision(),
      );
      final old = repository.find(const BookQuery(search: 'во'));
      final cancelled = expectLater(
        old,
        throwsA(isA<RequestCancelledException>()),
      );
      await started.future;
      final latest = await repository.find(const BookQuery(search: 'война'));
      await cancelled;
      expect(latest.items.single.title, 'Война и мир');
      expect(adapter.requests.first.cancelToken!.isCancelled, isTrue);
      oldResponse.complete(
        reply(pageJson([bookJson(title: 'Устаревший ответ')])),
      );
    },
  );

  test(
    'Справочники загружаются один раз при повторном открытии форм',
    () async {
      final adapter = FakeApiAdapter(referencesReply);
      final cache = ApiReferenceCache(fakeClient(adapter));
      await Future.wait([cache.ensure(), cache.ensure()]);
      await cache.ensure();
      expect(adapter.requests.length, 3);
      expect(cache.snapshot.authors.length, 10);
      expect(cache.snapshot.books, isEmpty);
      expect(cache.snapshot.readers, isEmpty);
      cache.dispose();
    },
  );

  test('POST книги отправляет только поля ввода', () async {
    final adapter = FakeApiAdapter((_) => reply(bookJson(), 201));
    final repository = ApiBookRepository(
      fakeClient(adapter),
      changes: ApiRevision(),
    );
    await repository.create(LibrarySnapshot.seed().books.first);
    final input = adapter.requests.single.data as Map;
    expect(input, containsPair('publisherId', 1));
    expect(input, contains('authorIds'));
    expect(input, contains('genreIds'));
    expect(input, isNot(contains('id')));
    expect(input, isNot(contains('createdAt')));
    expect(input, isNot(contains('copiesAvailable')));
  });

  test(
    'Все CRUD операции используют корректные адреса и меняют revision',
    () async {
      final adapter = FakeApiAdapter((options) {
        if (options.path.endsWith('bulk-delete')) return reply({'deleted': 2});
        if (options.method == 'DELETE') return reply(null, 204);
        return reply({
          'id': 7,
          'name': 'Жанр API',
          'description': '',
          'deletedAt': null,
        });
      });
      final revision = ApiRevision();
      final repository = ApiEntityRepository<Genre, ListQuery>(
        fakeClient(adapter),
        'genres',
        Genre.fromJson,
        changes: revision,
      );
      final item = await repository.create(
        const Genre(id: 0, name: 'Жанр API'),
      );
      await repository.update(item);
      await repository.findById(7);
      await repository.softDelete(7);
      await repository.restore(7);
      await repository.hardDelete(7);
      expect(await repository.deleteMany([7, 8]), 2);
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /genres',
        'PUT /genres/7',
        'GET /genres/7',
        'DELETE /genres/7',
        'POST /genres/7/restore',
        'DELETE /genres/7',
        'POST /genres/bulk-delete',
      ]);
      expect(adapter.requests[5].queryParameters['hard'], true);
      expect(revision.value, 6);
    },
  );

  test('Серверные ошибки 401/403/404 не превращаются в сетевые', () async {
    expect(mapHttpError(401, {}), isA<UnauthorizedException>());
    expect(mapHttpError(403, {}), isA<ForbiddenException>());
    final adapter = FakeApiAdapter(
      (_) => reply({'message': 'Нет записи'}, 404),
    );
    expect(
      await ApiBookRepository(
        fakeClient(adapter),
        changes: ApiRevision(),
      ).findById(999),
      isNull,
    );
    expect(adapter.requests.length, 1);
  });

  test('Двойное сохранение формы не создаёт вторую запись', () async {
    final response = Completer<ResponseBody>();
    final posted = Completer<void>();
    final adapter = FakeApiAdapter((options) {
      if (options.method == 'POST') {
        posted.complete();
        return response.future;
      }
      return referencesReply(options);
    });
    final client = fakeClient(adapter);
    final cache = ApiReferenceCache(client);
    final repos = LibraryRepositories.remote(client, cache);
    final refs = CatalogReferences(remote: cache);
    final form = EntityFormNotifier(repos, refs, 'authors', null);
    await form.load();
    form.setValue('fullName', 'Автор API');
    form.setValue('birthYear', '1980');
    form.setValue('country', 'Россия');
    final first = form.save();
    await posted.future;
    expect(form.saving, isTrue);
    expect(await form.save(), isNull);
    response.complete(
      reply({
        'id': 11,
        'fullName': 'Автор API',
        'birthYear': 1980,
        'country': 'Россия',
      }, 201),
    );
    expect((await first)!.id, 11);
    expect(adapter.requests.where((r) => r.method == 'POST').length, 1);
    form.dispose();
    refs.dispose();
    cache.dispose();
  });

  test(
    '422 из API попадает в состояние формы и очищается после изменения поля',
    () async {
      final adapter = FakeApiAdapter((options) {
        if (options.method == 'POST') {
          return reply({
            'errors': {'name': 'Сервер отклонил название'},
          }, 422);
        }
        return referencesReply(options);
      });
      final client = fakeClient(adapter);
      final cache = ApiReferenceCache(client);
      final refs = CatalogReferences(remote: cache);
      final form = EntityFormNotifier(
        LibraryRepositories.remote(client, cache),
        refs,
        'genres',
        null,
      );
      await form.load();
      form.setValue('name', 'Роман');
      expect(await form.save(), isNull);
      expect(form.fieldError('name'), 'Сервер отклонил название');
      form.setValue('name', 'Другое название');
      expect(form.fieldError('name'), isNull);
      form.dispose();
      refs.dispose();
      cache.dispose();
    },
  );

  test('Сетевая отмена не выводится как ошибка списка', () async {
    final adapter = FakeApiAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      ),
    );
    final state = BookListNotifier(
      ApiBookRepository(fakeClient(adapter), changes: ApiRevision()),
    );
    await state.applyQuery(const BookQuery());
    expect(state.error, isNull);
    state.dispose();
  });
}
