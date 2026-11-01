import '../data/seed_data.dart';
import '../models/book.dart';
import '../models/book_query.dart';
import 'entity_repository.dart';
import 'in_memory_repository.dart';
import 'repository_backend.dart';

class InMemoryBookRepository extends InMemoryRepository<Book, BookQuery>
    implements BookRepository {
  InMemoryBookRepository({RepositoryBackend<Book>? backend})
    : super(
        seedBooks,
        backend: backend,
        idOf: (book) => book.id,
        isDeleted: (book) => book.isDeleted,
        withId: (book, id) => book.copyWith(
          id: id,
          createdAt: book.createdAt ?? DateTime.now().toUtc(),
        ),
        withDeletedAt: (book, date) =>
            book.copyWith(deletedAt: date, clearDeletedAt: date == null),
      );

  @override
  bool matches(Book book, BookQuery query) {
    final search = query.search.trim().toLowerCase();

    if (search.isNotEmpty &&
        !book.title.toLowerCase().contains(search) &&
        !book.isbn.toLowerCase().contains(search)) {
      return false;
    }

    if (query.genreId != null && !book.genreIds.contains(query.genreId)) {
      return false;
    }

    if (query.publisherId != null && book.publisherId != query.publisherId) {
      return false;
    }

    if (query.yearFrom != null && book.year < query.yearFrom!) {
      return false;
    }

    if (query.yearTo != null && book.year > query.yearTo!) {
      return false;
    }

    return true;
  }

  @override
  int compare(Book a, Book b, String field) {
    return switch (field) {
      'year' => a.year.compareTo(b.year),
      'pages' => a.pages.compareTo(b.pages),
      _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    };
  }
}
