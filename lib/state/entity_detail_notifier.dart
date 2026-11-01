import 'package:flutter/foundation.dart';

import '../models/author.dart';
import '../models/book.dart';
import '../repositories/entity_repository.dart';
import '../repositories/catalog_exception.dart';
import 'entity_list_notifier.dart';

class EntityDetailNotifier<T> extends ChangeNotifier {
  EntityDetailNotifier(this._find);
  final Future<T?> Function(int) _find;
  T? _item;
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  int _request = 0;
  bool _disposed = false;

  T? get item => _item;
  LoadStatus get status => _status;
  String? get error => _error;

  Future<void> load(int id) async {
    if (_disposed) return;
    final request = ++_request;
    _status = LoadStatus.loading;
    notifyListeners();
    try {
      final item = await _find(id);
      if (_disposed || request != _request) return;
      _item = item;
      _error = item == null ? 'Запись не найдена или была удалена.' : null;
      _status = item == null ? LoadStatus.error : LoadStatus.success;
    } on CatalogException catch (failure) {
      if (_disposed || request != _request) return;
      _error = failure.message;
      _status = LoadStatus.error;
    } catch (_) {
      if (_disposed || request != _request) return;
      _error = 'Не удалось открыть запись. Попробуйте ещё раз.';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}

class BookDetailNotifier extends EntityDetailNotifier<Book> {
  BookDetailNotifier(
    BookRepository repository, {
    Future<void> Function()? beforeLoad,
  }) : super((id) async {
         if (beforeLoad != null) await beforeLoad();
         return repository.findById(id);
       });
}

class AuthorDetailNotifier extends EntityDetailNotifier<Author> {
  AuthorDetailNotifier(AuthorRepository repository)
    : super(repository.findById);
}
