import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/catalog_entity.dart';
import '../models/entity_draft.dart';
import '../models/json_values.dart';
import '../models/library_snapshot.dart';
import '../validation/entity_validation.dart';
import 'catalog_exception.dart';
import 'repository_backend.dart';

abstract interface class CatalogStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesCatalogStorage implements CatalogStorage {
  final _prefs = SharedPreferencesAsync();
  @override
  Future<String?> read(String key) => _prefs.getString(key);
  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

class MemoryCatalogStorage implements CatalogStorage {
  MemoryCatalogStorage([Map<String, String>? initial]) : values = {...?initial};
  final Map<String, String> values;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class LibraryDatabase extends ChangeNotifier {
  LibraryDatabase._(this._storage, this._snapshot, this.notice);
  factory LibraryDatabase.memory() =>
      LibraryDatabase._(MemoryCatalogStorage(), LibrarySnapshot.seed(), null);
  static const storageKey = 'library_catalog_v2';
  static const previousKey = 'library_catalog_v1';
  static const schemaVersion = 2;
  final CatalogStorage _storage;
  LibrarySnapshot _snapshot;
  LibrarySnapshot get snapshot => _snapshot;
  String? notice;
  int revision = 0;
  Future<void> _queue = Future.value();

  static Future<LibraryDatabase> open(CatalogStorage storage) async {
    final raw = await storage.read(storageKey);
    var snapshot = LibrarySnapshot.seed();
    String? notice;
    if (raw != null) {
      try {
        final root = JsonValues.map(jsonDecode(raw));
        if (root['schemaVersion'] != schemaVersion) {
          throw const FormatException('Версия формата');
        }
        snapshot = LibrarySnapshot.fromJson(root);
      } catch (_) {
        await storage.write(
          '${storageKey}_backup_${DateTime.now().millisecondsSinceEpoch}',
          raw,
        );
        notice =
            'Формат сохранённых данных изменился или данные повреждены. Сохранена резервная копия, загружен начальный каталог.';
      }
    } else if (await storage.read(previousKey) != null) {
      notice =
          'Каталог переведён на формат версии 2. Предыдущие данные сохранены в старом ключе; загружен начальный набор.';
    }
    final database = LibraryDatabase._(storage, snapshot, notice);
    if (raw == null || notice != null) await database._persist(snapshot);
    return database;
  }

  void dismissNotice() {
    notice = null;
    notifyListeners();
  }

  RepositoryBackend<T> backend<T extends CatalogEntity>(String section) =>
      _DatabaseBackend<T>(this, section);

  Future<void> _persist(LibrarySnapshot snapshot) => _storage.write(
    storageKey,
    jsonEncode({'schemaVersion': schemaVersion, ...snapshot.toJson()}),
  );

  Future<void> replace(String section, List<CatalogEntity> rows) {
    final operation = _queue.then((_) async {
      final previous = _snapshot.sections[section] ?? [];
      final next = _snapshot.replace(section, rows);
      final oldById = {for (final row in previous) row.id: row};
      final nextById = {for (final row in rows) row.id: row};
      if (nextById.length != rows.length || rows.any((row) => row.id < 1)) {
        throw const CatalogException('Некорректные идентификаторы записей.');
      }
      // Check the entire batch before touching either memory or localStorage.
      for (final old in previous) {
        final current = nextById[old.id];
        if (current == null ||
            (section == 'publishers' && !old.isDeleted && current.isDeleted)) {
          final count = EntityValidation.linkedBooks(
            _snapshot,
            section,
            old.id,
          );
          if (count > 0) {
            throw CatalogException(
              'Удаление невозможно: связанных книг — $count. Сначала измените их связи. Учитываются и логически удалённые книги.',
            );
          }
        }
      }
      for (final row in rows) {
        final old = oldById[row.id];
        if (old != null &&
            jsonEncode(old.toJson()) == jsonEncode(row.toJson())) {
          continue;
        }
        if (row.isDeleted) continue;
        final errors = EntityValidation.validate(
          section,
          entityDraft(row),
          next,
          id: row.id,
        );
        if (errors.isNotEmpty) {
          throw CatalogException(
            'Запись не сохранена: ${errors.values.toSet().join('. ')}',
            errors,
          );
        }
      }
      if (section == 'readers') {
        final cards = next.readers.map((reader) => reader.card.id).toList();
        if (cards.any((id) => id < 1) || cards.toSet().length != cards.length) {
          throw const CatalogException(
            'Читательский билет должен принадлежать одному читателю.',
          );
        }
      }
      await _persist(next);
      _snapshot = next;
      revision++;
      notifyListeners();
    });
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}

class _DatabaseBackend<T extends CatalogEntity>
    implements RepositoryBackend<T> {
  _DatabaseBackend(this.database, this.section);
  final LibraryDatabase database;
  final String section;
  @override
  List<T> get items => database.snapshot.items<T>(section);
  @override
  int get revision => database.revision;
  @override
  Future<void> replace(List<T> items) => database.replace(section, items);
}
