import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../models/reader.dart';
import '../repositories/api_loan_repository.dart';
import '../repositories/catalog_exception.dart';
import '../repositories/entity_repository.dart';
import '../validation/validators.dart';
import '../core/api_exceptions.dart';

class LoanIssueNotifier extends ChangeNotifier {
  LoanIssueNotifier(this.repository, this.books, this.bookId);
  final ApiLoanRepository repository;
  final BookRepository books;
  final int bookId;
  Book? book;
  List<Reader> readers = [];
  int? readerId;
  String days = '14';
  bool loading = true, searching = false, saving = false;
  String? error;
  final Map<String, String> errors = {};
  int _search = 0;
  bool _disposed = false;

  Future<void> load() async {
    loading = true;
    error = null;
    _emit();
    try {
      book = await books.findById(bookId);
      if (book == null) throw const CatalogException('Книга не найдена.');
      readers = await repository.readers('');
    } on CatalogException catch (failure) {
      error = failure.message;
    } finally {
      loading = false;
      _emit();
    }
  }

  Future<void> search(String text) async {
    final request = ++_search;
    searching = true;
    error = null;
    _emit();
    try {
      final result = await repository.readers(text);
      if (_disposed || request != _search) return;
      readers = result;
      if (!readers.any((r) => r.id == readerId)) readerId = null;
    } on RequestCancelledException {
      // A newer search owns the loading state and result.
    } on CatalogException catch (failure) {
      if (request == _search) error = failure.message;
    } finally {
      if (request == _search) {
        searching = false;
        _emit();
      }
    }
  }

  void cancelSearch() {
    _search++;
    repository.cancelReaderSearch();
  }

  void select(int? value) {
    readerId = value;
    errors.remove('readerId');
    _emit();
  }

  void setDays(String value) {
    days = value;
    errors.remove('days');
  }

  Future<int?> save() async {
    if (saving || loading || searching || book == null) return null;
    errors.clear();
    error = null;
    if (readerId == null) errors['readerId'] = 'Выберите читателя';
    final invalidDays = Validators.integer(days, min: 1, max: 90);
    if (invalidDays != null) errors['days'] = invalidDays;
    if (errors.isNotEmpty) {
      _emit();
      return null;
    }
    saving = true;
    _emit();
    try {
      return await repository.issue(
        bookId: bookId,
        readerId: readerId!,
        days: Validators.parseInteger(days)!,
      );
    } on CatalogException catch (failure) {
      errors.addAll(failure.fields);
      error = failure.message;
      return null;
    } finally {
      saving = false;
      _emit();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancelSearch();
    super.dispose();
  }
}
