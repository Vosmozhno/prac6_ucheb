import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/author.dart';
import '../models/book.dart';
import '../models/book_query.dart';
import '../models/catalog_entity.dart';
import '../models/json_values.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import 'api_reference_cache.dart';
import 'cancellable_repository.dart';
import 'entity_repository.dart';

class ApiRevision {
  int value = 0;
}

class ApiEntityRepository<T extends CatalogEntity, Q extends ListQuery>
    implements EntityRepository<T, Q>, CancellableRepository {
  ApiEntityRepository(
    this.client,
    this.section,
    this.decode, {
    required this.changes,
    this.references,
  });
  final ApiClient client;
  final String section;
  final T Function(Map<String, dynamic>) decode;
  final ApiRevision changes;
  final ApiReferenceCache? references;
  CancelToken? _pending;
  @override
  int get revision => changes.value;
  @override
  void cancelPending() {
    _pending?.cancel('Условия списка изменились');
  }

  Map<String, dynamic> parameters(Q query) => query.toQueryParameters();
  @override
  Future<PageResult<T>> find(Q query) async {
    cancelPending();
    final token = _pending = CancelToken();
    final params = parameters(query);
    final response = await client.request(
      'GET',
      '/$section',
      query: params,
      cancelToken: token,
    );
    final data = _object(response.data);
    final total = JsonValues.integer(data['total']);
    final size = JsonValues.integer(data['size'], query.size);
    final page = JsonValues.integer(data['page'], query.page);
    if (size < 1 || page < 1 || total < 0) {
      throw const ServerException(
        'API вернул некорректные параметры страницы.',
      );
    }
    final last = total == 0 ? 1 : (total + size - 1) ~/ size;
    if (page > last) {
      final corrected = await client.request(
        'GET',
        '/$section',
        query: {...params, 'page': last},
        cancelToken: token,
      );
      return _page(corrected.data, query);
    }
    return _page(data, query);
  }

  PageResult<T> _page(Object? raw, Q query) {
    final data = _object(raw);
    if (data['items'] is! List) {
      throw const ServerException('API вернул некорректный список.');
    }
    return PageResult(
      items: (data['items'] as List)
          .map((row) => decode(_object(row)))
          .toList(),
      page: JsonValues.integer(data['page'], query.page),
      size: JsonValues.integer(data['size'], query.size),
      total: JsonValues.integer(data['total']),
    );
  }

  @override
  Future<List<T>> all({bool includeDeleted = false}) async {
    final result = <T>[];
    for (var page = 1; ; page++) {
      final response = await client.request(
        'GET',
        '/$section',
        query: {
          'page': page,
          'size': 100,
          if (includeDeleted) 'includeDeleted': true,
        },
      );
      final data = _object(response.data);
      if (data['items'] is! List) {
        throw const ServerException('API вернул некорректный список.');
      }
      final rows = data['items'] as List;
      result.addAll(rows.map((row) => decode(_object(row))));
      if (result.length >= JsonValues.integer(data['total']) || rows.isEmpty) {
        return result;
      }
    }
  }

  @override
  Future<T?> findById(int id) async {
    try {
      final response = await client.request('GET', '/$section/$id');
      return decode(_object(response.data));
    } on NotFoundException {
      return null;
    }
  }

  Map<String, dynamic> input(T item) {
    final json = item.toJson();
    json.remove('id');
    json.remove('createdAt');
    json.remove('deletedAt');
    json.remove('copiesAvailable');
    if (json['card'] is Map) {
      json['card'] = Map<String, dynamic>.from(json['card'] as Map)
        ..remove('id');
    }
    return json;
  }

  Future<T> _write(String method, String path, T item) async {
    final response = await client.request(method, path, data: input(item));
    final saved = decode(_object(response.data));
    changes.value++;
    references?.update(section, saved);
    return saved;
  }

  @override
  Future<T> create(T item) => _write('POST', '/$section', item);
  @override
  Future<T> update(T item) => _write('PUT', '/$section/${item.id}', item);
  @override
  Future<void> softDelete(int id) async {
    await client.request('DELETE', '/$section/$id');
    changes.value++;
    references?.remove(section, [id]);
  }

  @override
  Future<void> hardDelete(int id) async {
    await client.request('DELETE', '/$section/$id', query: {'hard': true});
    changes.value++;
    references?.remove(section, [id], hard: true);
  }

  @override
  Future<void> restore(int id) async {
    final result = await client.request('POST', '/$section/$id/restore');
    changes.value++;
    references?.update(section, decode(_object(result.data)));
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    final result = await client.request(
      'POST',
      '/$section/bulk-delete',
      data: {'ids': ids},
    );
    changes.value++;
    references?.remove(section, ids);
    return JsonValues.integer(_object(result.data)['deleted']);
  }
}

class ApiBookRepository extends ApiEntityRepository<Book, BookQuery>
    implements BookRepository {
  ApiBookRepository(
    ApiClient client, {
    required super.changes,
    super.references,
  }) : super(client, 'books', Book.fromJson);
}

class ApiAuthorRepository extends ApiEntityRepository<Author, ListQuery>
    implements AuthorRepository {
  ApiAuthorRepository(
    ApiClient client, {
    required super.changes,
    super.references,
  }) : super(client, 'authors', Author.fromJson);
}

Map<String, dynamic> _object(Object? raw) {
  if (raw is! Map) {
    throw const ServerException('Сервер вернул данные в неожиданном формате.');
  }
  return Map<String, dynamic>.from(raw);
}
