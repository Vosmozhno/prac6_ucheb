import '../models/list_query.dart';
import '../models/page_result.dart';
import 'entity_repository.dart';
import 'repository_backend.dart';

abstract class InMemoryRepository<T, Q extends ListQuery>
    implements EntityRepository<T, Q> {
  InMemoryRepository(
    Iterable<T> seed, {
    required int Function(T) idOf,
    required bool Function(T) isDeleted,
    required T Function(T, int) withId,
    required T Function(T, DateTime?) withDeletedAt,
    RepositoryBackend<T>? backend,
  }) : _memoryRows = List.of(seed),
       _idOf = idOf,
       _isDeleted = isDeleted,
       _withId = withId,
       _withDeletedAt = withDeletedAt,
       _backend = backend {
    for (final row in _rows) {
      if (_idOf(row) >= _nextId) _nextId = _idOf(row) + 1;
    }
  }
  List<T> _memoryRows;
  final RepositoryBackend<T>? _backend;
  List<T> get _rows => _backend?.items ?? _memoryRows;
  final int Function(T) _idOf;
  final bool Function(T) _isDeleted;
  final T Function(T, int) _withId;
  final T Function(T, DateTime?) _withDeletedAt;
  int _nextId = 1;
  int _revision = 0;
  Future<void> _queue = Future.value();
  @override
  int get revision => _backend?.revision ?? _revision;
  bool matches(T item, Q query);
  int compare(T a, T b, String field);
  @override
  Future<List<T>> all({bool includeDeleted = false}) async => List.unmodifiable(
    _rows.where((row) => includeDeleted || !_isDeleted(row)),
  );

  @override
  Future<PageResult<T>> find(Q query) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final rows = _rows
        .where(
          (row) =>
              (query.includeDeleted || !_isDeleted(row)) && matches(row, query),
        )
        .toList();
    rows.sort((a, b) {
      final result = compare(a, b, query.sortField);
      return result == 0
          ? _idOf(a).compareTo(_idOf(b))
          : query.sortAscending
          ? result
          : -result;
    });
    final size = ListQuery.pageSizes.contains(query.size) ? query.size : 10;
    final total = rows.length;
    final pages = total == 0 ? 1 : (total + size - 1) ~/ size;
    final page = query.page < 1
        ? 1
        : query.page > pages
        ? pages
        : query.page;
    final from = (page - 1) * size;
    final end = from + size > total ? total : from + size;
    return PageResult(
      items: rows.sublist(from, end),
      page: page,
      size: size,
      total: total,
    );
  }

  @override
  Future<T?> findById(int id) async {
    for (final row in _rows) {
      if (_idOf(row) == id && !_isDeleted(row)) return row;
    }
    return null;
  }

  Future<R> _serialize<R>(Future<R> Function() action) {
    final operation = _queue.then((_) => action());
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<void> _commit(List<T> rows) async {
    if (_backend != null) {
      await _backend.replace(rows);
    } else {
      _memoryRows = rows;
    }
    _revision++;
  }

  int _index(List<T> rows, int id) {
    final index = rows.indexWhere((row) => _idOf(row) == id);
    if (index < 0) throw StateError('Запись $id не найдена');
    return index;
  }

  @override
  Future<T> create(T item) => _serialize(() async {
    final rows = List<T>.of(_rows);
    var next = _nextId;
    for (final row in rows) {
      if (_idOf(row) >= next) next = _idOf(row) + 1;
    }
    final created = _withDeletedAt(_withId(item, next), null);
    rows.add(created);
    await _commit(rows);
    _nextId = next + 1;
    return created;
  });
  @override
  Future<T> update(T item) => _serialize(() async {
    final rows = List<T>.of(_rows);
    rows[_index(rows, _idOf(item))] = item;
    await _commit(rows);
    return item;
  });
  @override
  Future<void> softDelete(int id) => _serialize(() async {
    final rows = List<T>.of(_rows);
    final index = _index(rows, id);
    if (_isDeleted(rows[index])) return;
    rows[index] = _withDeletedAt(rows[index], DateTime.now().toUtc());
    await _commit(rows);
  });
  @override
  Future<void> hardDelete(int id) => _serialize(() async {
    final rows = List<T>.of(_rows);
    rows.removeAt(_index(rows, id));
    await _commit(rows);
  });
  @override
  Future<void> restore(int id) => _serialize(() async {
    final rows = List<T>.of(_rows);
    final index = _index(rows, id);
    rows[index] = _withDeletedAt(rows[index], null);
    await _commit(rows);
  });
  @override
  Future<int> deleteMany(List<int> ids) => _serialize(() async {
    final selected = ids.toSet();
    final rows = List<T>.of(_rows);
    final now = DateTime.now().toUtc();
    var count = 0;
    for (var i = 0; i < rows.length; i++) {
      if (selected.contains(_idOf(rows[i])) && !_isDeleted(rows[i])) {
        rows[i] = _withDeletedAt(rows[i], now);
        count++;
      }
    }
    if (count > 0) await _commit(rows);
    return count;
  });
}
