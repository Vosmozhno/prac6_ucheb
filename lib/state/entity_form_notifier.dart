import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/catalog_entity.dart';
import '../models/entity_draft.dart';
import '../models/form_schema.dart';
import '../models/json_values.dart';
import '../repositories/library_repositories.dart';
import '../validation/validators.dart';
import 'dart:async';
import '../repositories/catalog_exception.dart';
import 'catalog_references.dart';

class EntityFormNotifier extends ChangeNotifier {
  EntityFormNotifier(this.repositories, this.references, this.section, this.id);
  final LibraryRepositories repositories;
  final CatalogReferences references;
  final String section;
  final int? id;
  final Map<String, dynamic> _values = {};
  final Map<String, String> _fieldErrors = {};
  Map<String, dynamic> get values => Map.unmodifiable(_values);
  List<CatalogFieldSpec> get fields => catalogFormFields[section]!;
  CatalogEntity? _original;
  String _initial = '';
  bool loading = true;
  bool _ready = false;
  bool saving = false;
  bool relatedLoading = false;
  bool get busy => saving || relatedLoading;
  int _publisherRequest = 0;
  bool showAllRelated = false;
  bool _disposed = false;
  String? error;
  bool get isEditing => id != null;
  String _fingerprint() {
    final normalized = Map<String, dynamic>.of(_values);
    for (final field in fields) {
      final value = normalized[field.key];
      if (field.kind == CatalogFieldKind.integer) {
        normalized[field.key] = Validators.parseInteger(value) ?? value;
      } else if (field.kind == CatalogFieldKind.authors ||
          field.kind == CatalogFieldKind.genres) {
        normalized[field.key] = JsonValues.ids(value)..sort();
      }
    }
    return jsonEncode(normalized);
  }

  bool get dirty => _ready && !loading && _initial != _fingerprint();
  int? get publisherId =>
      _values['publisherId'] is int ? _values['publisherId'] as int : null;

  Future<void> load() async {
    try {
      await references.ensure();
      if (id != null) {
        final entity = await repositories.findById(section, id!);
        if (_disposed) return;
        if (entity == null) {
          error = 'Запись не найдена или удалена. Вернитесь к списку.';
          loading = false;
          _emit();
          return;
        }
        _original = entity;
        _values.addAll(entityDraft(entity));
      } else {
        for (final field in fields) {
          _values[field.key] = switch (field.kind) {
            CatalogFieldKind.authors || CatalogFieldKind.genres => <int>[],
            CatalogFieldKind.publisher => null,
            _ => '',
          };
        }
        if (section == 'books') {
          _values['year'] = DateTime.now().year;
          _values['copiesTotal'] = 1;
          _values['_borrowed'] = 0;
        }
        if (section == 'readers') {
          final rows = references.data.readers;
          var next = 1;
          for (final reader in rows) {
            if (reader.id >= next) next = reader.id + 1;
          }
          _values['card.number'] = references.isRemote
              ? 'RC-${DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase()}'
              : 'RC-${next.toString().padLeft(6, '0')}';
          final now = DateTime.now();
          _values['card.issuedAt'] = Validators.dateText(
            DateTime.utc(now.year, now.month, now.day),
          );
          _values['card.expiresAt'] = Validators.dateText(
            DateTime.utc(now.year + 1, now.month, now.day),
          );
        }
      }
      if (section == 'books') {
        await references.loadPublisherOptions(publisherId);
      }
      if (_disposed) return;
      _initial = _fingerprint();
      _ready = true;
    } on CatalogException catch (failure) {
      error = failure.message;
    } catch (_) {
      error =
          'Не удалось открыть форму. Вернитесь к списку и повторите попытку.';
    }
    loading = false;
    _emit();
  }

  void setValue(String key, Object? value) {
    if (saving) return;
    _values[key] = value;
    _fieldErrors.remove(key);
    error = null;
    if (key == 'publisherId') {
      showAllRelated = false;
      if (references.isRemote) {
        unawaited(_loadRelated());
      } else {
        _trimRelated();
      }
      _fieldErrors.remove('authorIds');
      _fieldErrors.remove('genreIds');
    }
    _emit();
  }

  void _trimRelated() {
    final authors = references.availableAuthors(publisherId).keys.toSet();
    final genres = references.availableGenres(publisherId).keys.toSet();
    _values['authorIds'] = JsonValues.ids(
      _values['authorIds'],
    ).where(authors.contains).toList();
    _values['genreIds'] = JsonValues.ids(
      _values['genreIds'],
    ).where(genres.contains).toList();
  }

  Future<void> _loadRelated() async {
    final request = ++_publisherRequest;
    relatedLoading = true;
    try {
      await references.loadPublisherOptions(publisherId);
      if (_disposed || request != _publisherRequest) return;
      _trimRelated();
    } on CatalogException catch (failure) {
      if (!_disposed && request == _publisherRequest) error = failure.message;
    } finally {
      if (!_disposed && request == _publisherRequest) {
        relatedLoading = false;
        _emit();
      }
    }
  }

  void setRelatedScope(bool all) {
    if (saving) return;
    showAllRelated = all;
    if (!all) {
      final authors = references.availableAuthors(publisherId).keys.toSet();
      final genres = references.availableGenres(publisherId).keys.toSet();
      _values['authorIds'] = JsonValues.ids(
        _values['authorIds'],
      ).where(authors.contains).toList();
      _values['genreIds'] = JsonValues.ids(
        _values['genreIds'],
      ).where(genres.contains).toList();
    }
    _emit();
  }

  String? fieldError(String key) =>
      _fieldErrors[key] ?? repositories.validate(section, _values, id: id)[key];

  Future<CatalogEntity?> save() async {
    if (busy || loading || _disposed) return null;
    _fieldErrors.clear();
    _fieldErrors.addAll(repositories.validate(section, _values, id: id));
    if (_fieldErrors.isNotEmpty) {
      _emit();
      return null;
    }
    saving = true;
    error = null;
    _emit();
    try {
      final saved = await repositories.save(
        section,
        Map.of(_values),
        original: _original,
      );
      if (_disposed) return saved;
      _values.clear();
      _values.addAll(entityDraft(saved));
      _initial = _fingerprint();
      _original = saved;
      return saved;
    } on CatalogException catch (failure) {
      _fieldErrors.addAll(failure.fields);
      if (failure.fields.isEmpty) error = failure.message;
      return null;
    } catch (_) {
      error =
          'Не удалось сохранить данные. Изменения остались в форме; повторите попытку.';
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
    super.dispose();
  }
}
