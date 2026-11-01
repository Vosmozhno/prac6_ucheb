import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/api_exceptions.dart';
import '../models/author.dart';
import '../models/catalog_entity.dart';
import '../models/genre.dart';
import '../models/json_values.dart';
import '../models/library_snapshot.dart';
import '../models/publisher.dart';

class PublisherOptions {
  PublisherOptions(Map<String, dynamic> json)
    : hasBooks = json['hasBooks'] == true,
      authorIds = JsonValues.ids(json['authorIds']).toSet(),
      genreIds = JsonValues.ids(json['genreIds']).toSet();
  final bool hasBooks;
  final Set<int> authorIds;
  final Set<int> genreIds;
}

class ApiReferenceCache extends ChangeNotifier {
  ApiReferenceCache(this.client);
  final ApiClient client;
  final Map<String, List<CatalogEntity>> _rows = {
    'authors': [],
    'genres': [],
    'publishers': [],
  };
  final Map<int, PublisherOptions> options = {};
  final Map<int, Future<void>> _pendingOptions = {};
  Future<void>? _pending;
  bool loaded = false;
  bool _disposed = false;
  LibrarySnapshot get snapshot =>
      LibrarySnapshot({..._rows, 'books': [], 'readers': []});

  Future<void> ensure() async {
    if (loaded) return;
    if (_pending != null) return _pending!;
    _pending = _load();
    try {
      await _pending;
    } finally {
      _pending = null;
    }
  }

  Future<void> _load() async {
    final entries = await Future.wait(
      _rows.keys.map((section) async {
        final rows = <CatalogEntity>[];
        for (var page = 1; ; page++) {
          final response = await client.request(
            'GET',
            '/$section',
            query: {'page': page, 'size': 100, 'includeDeleted': true},
          );
          final data = _object(response.data);
          if (data['items'] is! List) throw const FormatException();
          final items = data['items'] as List;
          for (final raw in items) {
            final json = _object(raw);
            rows.add(switch (section) {
              'authors' => Author.fromJson(json),
              'genres' => Genre.fromJson(json),
              _ => Publisher.fromJson(json),
            });
          }
          if (rows.length >= JsonValues.integer(data['total']) ||
              items.isEmpty) {
            break;
          }
        }
        return MapEntry(section, rows);
      }),
    );
    if (_disposed) return;
    _rows.addEntries(entries);
    loaded = true;
    notifyListeners();
  }

  Future<void> loadOptions(int publisherId) async {
    if (options.containsKey(publisherId)) return;
    if (_pendingOptions.containsKey(publisherId)) {
      return _pendingOptions[publisherId]!;
    }
    final request = _loadOptions(publisherId);
    _pendingOptions[publisherId] = request;
    try {
      await request;
    } finally {
      _pendingOptions.remove(publisherId);
    }
  }

  Future<void> _loadOptions(int id) async {
    final result = await client.request('GET', '/publishers/$id/options');
    if (_disposed) return;
    options[id] = PublisherOptions(_object(result.data));
    notifyListeners();
  }

  void update(String section, CatalogEntity item) {
    final rows = _rows[section];
    if (rows != null) {
      final index = rows.indexWhere((row) => row.id == item.id);
      index == -1 ? rows.add(item) : rows[index] = item;
    }
    options.clear();
    if (!_disposed) notifyListeners();
  }

  void remove(String section, List<int> ids, {bool hard = false}) {
    final rows = _rows[section];
    if (rows != null) {
      if (hard) {
        rows.removeWhere((row) => ids.contains(row.id));
      } else {
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (!ids.contains(row.id)) continue;
          rows[i] = switch (row) {
            Author a => a.copyWith(deletedAt: DateTime.now().toUtc()),
            Genre g => g.copyWith(deletedAt: DateTime.now().toUtc()),
            Publisher p => p.copyWith(deletedAt: DateTime.now().toUtc()),
            _ => row,
          };
        }
      }
    }
    options.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Map<String, dynamic> _object(Object? raw) {
  if (raw is! Map) {
    throw const ServerException('Неожиданный формат справочника API.');
  }
  return Map<String, dynamic>.from(raw);
}
