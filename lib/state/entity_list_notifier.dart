import 'package:flutter/foundation.dart';

import '../models/list_query.dart';
import '../models/page_result.dart';
import '../repositories/entity_repository.dart';
import '../repositories/catalog_exception.dart';
import '../repositories/cancellable_repository.dart';
import '../core/api_exceptions.dart';

enum LoadStatus { idle, loading, success, error }

abstract class EntityListNotifier<T, Q extends ListQuery>
    extends ChangeNotifier {
  EntityListNotifier(
    this._repository, {
    required Q initialQuery,
    required this.idOf,
    required this.isDeleted,
    this.beforeLoad,
  }) : _query = initialQuery;

  final EntityRepository<T, Q> _repository;
  final Future<void> Function()? beforeLoad;
  final int Function(T) idOf;
  final bool Function(T) isDeleted;
  Q _query;
  PageResult<T> _result = PageResult<T>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  int _request = 0;
  bool _disposed = false;
  bool _busy = false;
  bool _simulateError = false;
  int _loadedRevision = -1;
  String? _operationError;

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set<int>.unmodifiable(_selected);
  bool get busy => _busy;
  bool get needsReload =>
      _status == LoadStatus.success && _loadedRevision != _repository.revision;
  String? get operationError => _operationError;
  void clearOperationError() {
    _operationError = null;
    _emit();
  }

  Q updated({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    String? filter,
  });

  Future<void> applyQuery(Q next, {bool simulateError = false}) async {
    if (_status == LoadStatus.success &&
        _loadedRevision == _repository.revision &&
        next.toUri('/').toString() == _query.toUri('/').toString() &&
        simulateError == _simulateError) {
      return;
    }
    _query = next;
    _simulateError = simulateError;
    _selected.clear();
    await load();
  }

  Future<void> load() async {
    if (_disposed) return;
    final request = ++_request;
    final currentQuery = _query;
    _status = LoadStatus.loading;
    _error = null;
    _emit();
    try {
      if (_simulateError && _repository is! CancellableRepository) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        throw StateError('Учебная ошибка загрузки. Повторите запрос.');
      }
      if (beforeLoad != null) await beforeLoad!();
      if (_disposed || request != _request) return;
      final result = await _repository.find(currentQuery);
      if (_disposed || request != _request) return;
      _result = result;
      _loadedRevision = _repository.revision;
      _query = updated(page: result.page, size: result.size);
      _status = LoadStatus.success;
    } on RequestCancelledException {
      return;
    } on CatalogException catch (failure) {
      if (_disposed || request != _request) return;
      _error = failure.message;
      _status = LoadStatus.error;
    } catch (_) {
      if (_disposed || request != _request) return;
      _error = _simulateError
          ? 'Учебный сценарий ошибки. Нажмите «Повторить», чтобы загрузить каталог.'
          : 'Не удалось загрузить список. Попробуйте ещё раз.';
      _status = LoadStatus.error;
    }
    _emit();
  }

  void cancelPending() {
    if (_repository case CancellableRepository managed) {
      _request++;
      managed.cancelPending();
    }
  }

  void toggleSelection(int id) {
    if (_busy || _status != LoadStatus.success) return;
    if (!_result.items.any((item) => idOf(item) == id && !isDeleted(item))) {
      return;
    }
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _emit();
  }

  void selectAll(bool selected) {
    if (_busy || _status != LoadStatus.success) return;
    _selected.clear();
    if (selected) {
      _selected.addAll(
        _result.items.where((item) => !isDeleted(item)).map(idOf),
      );
    }
    _emit();
  }

  void clearSelection() {
    _selected.clear();
    _emit();
  }

  Future<bool> deleteIds(List<int> ids) => _mutate(() async {
    await _repository.deleteMany(ids);
  });
  Future<bool> softDelete(int id) => _mutate(() => _repository.softDelete(id));
  Future<bool> hardDelete(int id) => _mutate(() => _repository.hardDelete(id));
  Future<bool> restore(int id) => _mutate(() => _repository.restore(id));

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (_busy || _disposed) return false;
    _busy = true;
    _operationError = null;
    _emit();
    try {
      await operation();
      if (_disposed) return false;
      _selected.clear();
      await load();
      return _status == LoadStatus.success;
    } on CatalogException catch (error) {
      _operationError = error.message;
      return false;
    } catch (_) {
      if (_disposed) return false;
      _operationError =
          'Не удалось выполнить действие. Обновите список и повторите попытку.';
      return false;
    } finally {
      _busy = false;
      _emit();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancelPending();
    _request++;
    super.dispose();
  }
}
