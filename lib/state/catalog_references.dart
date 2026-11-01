import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../models/library_snapshot.dart';
import '../repositories/library_database.dart';
import '../repositories/api_reference_cache.dart';

class CatalogReferences extends ChangeNotifier {
  CatalogReferences({LibraryDatabase? database, ApiReferenceCache? remote})
    : _database = database,
      _remote = remote {
    _database?.addListener(notifyListeners);
    _remote?.addListener(notifyListeners);
  }
  final LibraryDatabase? _database;
  final ApiReferenceCache? _remote;
  bool get isRemote => _remote != null;
  Future<void> ensure() async {
    await _remote?.ensure();
  }

  Future<void> loadPublisherOptions(int? id) async {
    if (id != null) await _remote?.loadOptions(id);
  }

  late final LibrarySnapshot _fallback = LibrarySnapshot.seed();
  LibrarySnapshot get data =>
      _remote?.snapshot ?? _database?.snapshot ?? _fallback;
  Map<int, String> get publishers => {
    for (final p in data.publishers) p.id: p.name,
  };
  Map<int, String> get genres => {for (final g in data.genres) g.id: g.name};
  Map<int, String> get authors => {
    for (final a in data.authors) a.id: a.fullName,
  };
  Map<int, String> get activePublishers => {
    for (final p in data.publishers)
      if (!p.isDeleted) p.id: p.name,
  };
  Map<int, String> get activeGenres => {
    for (final g in data.genres)
      if (!g.isDeleted) g.id: g.name,
  };
  Map<int, String> get activeAuthors => {
    for (final a in data.authors)
      if (!a.isDeleted) a.id: a.fullName,
  };
  String publisherName(int id) => publishers[id] ?? 'Издательство #$id';
  String genreName(int id) => genres[id] ?? 'Жанр #$id';
  String authorName(int id) => authors[id] ?? 'Автор #$id';
  List<Book> publisherBooks(int? id) => id == null
      ? []
      : data.books
            .where((book) => book.publisherId == id && !book.isDeleted)
            .toList();
  bool hasPublisherBooks(int? id) => isRemote
      ? _remote!.options[id]?.hasBooks ?? false
      : publisherBooks(id).isNotEmpty;
  Map<int, String> availableAuthors(int? publisherId) {
    if (isRemote && publisherId != null) {
      final options = _remote!.options[publisherId];
      if (options == null || !options.hasBooks) return activeAuthors;
      return {
        for (final entry in activeAuthors.entries)
          if (options.authorIds.contains(entry.key)) entry.key: entry.value,
      };
    }
    final books = publisherBooks(publisherId);
    if (books.isEmpty) return activeAuthors;
    final allowed = books.expand((b) => b.authorIds).toSet();
    return {
      for (final entry in activeAuthors.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
  }

  Map<int, String> availableGenres(int? publisherId) {
    if (isRemote && publisherId != null) {
      final options = _remote!.options[publisherId];
      if (options == null || !options.hasBooks) return activeGenres;
      return {
        for (final entry in activeGenres.entries)
          if (options.genreIds.contains(entry.key)) entry.key: entry.value,
      };
    }
    final books = publisherBooks(publisherId);
    if (books.isEmpty) return activeGenres;
    final allowed = books.expand((b) => b.genreIds).toSet();
    return {
      for (final entry in activeGenres.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
  }

  @override
  void dispose() {
    _database?.removeListener(notifyListeners);
    _remote?.removeListener(notifyListeners);
    super.dispose();
  }
}
