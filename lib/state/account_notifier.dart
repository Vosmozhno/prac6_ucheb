import 'package:flutter/foundation.dart';
import '../core/api_exceptions.dart';
import '../models/json_values.dart';
import '../repositories/account_repository.dart';

class AccountNotifier extends ChangeNotifier {
  AccountNotifier(this.repository, this.section);
  final AccountRepository repository;
  final String section;
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> statistics = {};
  String? error, message;
  int page = 1, totalPages = 1, total = 0;
  bool loading = true, busy = false, _disposed = false;
  int _generation = 0;
  Future<void> load({int? requestedPage}) async {
    if (requestedPage != null) page = requestedPage;
    final generation = ++_generation;
    loading = true;
    error = null;
    _emit();
    try {
      final json = await repository.load(section, page: page);
      if (_disposed || generation != _generation) return;
      if (section == 'stats') {
        statistics = json;
      } else {
        items = (json['items'] as List? ?? []).map(JsonValues.map).toList();
        totalPages = JsonValues.integer(json['totalPages']);
        if (totalPages < 1) totalPages = 1;
        total = JsonValues.integer(json['total']);
      }
    } on ApiException catch (failure) {
      if (!_disposed && generation == _generation) {
        error = failure is ForbiddenException
            ? '403: ${failure.message}'
            : failure.message;
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> act(Future<void> Function() operation, String success) async {
    if (busy) return;
    busy = true;
    error = null;
    message = null;
    _emit();
    try {
      await operation();
      message = success;
      await load();
    } on ApiException catch (failure) {
      error = failure is ForbiddenException
          ? '403: ${failure.message}'
          : failure.message;
    } finally {
      busy = false;
      _emit();
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
