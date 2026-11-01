import '../models/genre.dart';
import '../models/list_query.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import '../validation/entity_validation.dart';
import 'in_memory_repository.dart';
import 'library_database.dart';

class GenreRepository extends InMemoryRepository<Genre, ListQuery> {
  GenreRepository(this.database)
    : super(
        database.snapshot.genres,
        backend: database.backend<Genre>('genres'),
        idOf: (g) => g.id,
        isDeleted: (g) => g.isDeleted,
        withId: (g, id) => g.copyWith(id: id),
        withDeletedAt: (g, date) =>
            g.copyWith(deletedAt: date, clearDeletedAt: date == null),
      );
  final LibraryDatabase database;
  @override
  bool matches(Genre item, ListQuery query) {
    final search = query.search.trim().toLowerCase();
    final count = EntityValidation.linkedBooks(
      database.snapshot,
      'genres',
      item.id,
    );
    return (search.isEmpty ||
            ('${item.name} ${item.description}').toLowerCase().contains(
              search,
            )) &&
        (query.filter != 'used' || count > 0) &&
        (query.filter != 'unused' || count == 0);
  }

  @override
  int compare(Genre a, Genre b, String field) => switch (field) {
    'id' => a.id.compareTo(b.id),
    'description' => a.description.toLowerCase().compareTo(
      b.description.toLowerCase(),
    ),
    _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  };
}

class PublisherRepository extends InMemoryRepository<Publisher, ListQuery> {
  PublisherRepository(LibraryDatabase database)
    : super(
        database.snapshot.publishers,
        backend: database.backend<Publisher>('publishers'),
        idOf: (p) => p.id,
        isDeleted: (p) => p.isDeleted,
        withId: (p, id) => p.copyWith(id: id),
        withDeletedAt: (p, date) =>
            p.copyWith(deletedAt: date, clearDeletedAt: date == null),
      );
  @override
  bool matches(Publisher item, ListQuery query) {
    final search = query.search.trim().toLowerCase();
    return (query.filter.isEmpty || item.city == query.filter) &&
        (search.isEmpty ||
            ('${item.name} ${item.city}').toLowerCase().contains(search));
  }

  @override
  int compare(Publisher a, Publisher b, String field) => switch (field) {
    'city' => a.city.toLowerCase().compareTo(b.city.toLowerCase()),
    'foundedYear' => a.foundedYear.compareTo(b.foundedYear),
    _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  };
}

class ReaderRepository extends InMemoryRepository<Reader, ListQuery> {
  ReaderRepository(LibraryDatabase database)
    : super(
        database.snapshot.readers,
        backend: database.backend<Reader>('readers'),
        idOf: (r) => r.id,
        isDeleted: (r) => r.isDeleted,
        withId: (r, id) => r.copyWith(
          id: id,
          card: r.card.copyWith(id: r.card.id == 0 ? id : r.card.id),
        ),
        withDeletedAt: (r, date) =>
            r.copyWith(deletedAt: date, clearDeletedAt: date == null),
      );
  @override
  bool matches(Reader item, ListQuery query) {
    final search = query.search.trim().toLowerCase();
    final date = item.card.expiresAt;
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final valid = date != null && !date.isBefore(today);
    return (search.isEmpty ||
            ('${item.fullName} ${item.email} ${item.phone} ${item.card.number}')
                .toLowerCase()
                .contains(search)) &&
        (query.filter != 'valid' || valid) &&
        (query.filter != 'expired' || !valid);
  }

  @override
  int compare(Reader a, Reader b, String field) => switch (field) {
    'email' => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
    'expiresAt' => (a.card.expiresAt ?? DateTime(1970)).compareTo(
      b.card.expiresAt ?? DateTime(1970),
    ),
    _ => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
  };
}
