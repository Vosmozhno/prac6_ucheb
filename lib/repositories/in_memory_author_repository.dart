import '../data/seed_data.dart';
import '../models/author.dart';
import '../models/list_query.dart';
import 'entity_repository.dart';
import 'in_memory_repository.dart';
import 'repository_backend.dart';

class InMemoryAuthorRepository extends InMemoryRepository<Author, ListQuery>
    implements AuthorRepository {
  InMemoryAuthorRepository({RepositoryBackend<Author>? backend})
    : super(
        seedAuthors,
        backend: backend,
        idOf: (author) => author.id,
        isDeleted: (author) => author.isDeleted,
        withId: (author, id) => author.copyWith(id: id),
        withDeletedAt: (author, date) =>
            author.copyWith(deletedAt: date, clearDeletedAt: date == null),
      );

  @override
  bool matches(Author author, ListQuery query) {
    final search = query.search.trim().toLowerCase();

    if (query.filter.isNotEmpty && author.country != query.filter) return false;
    return search.isEmpty ||
        author.fullName.toLowerCase().contains(search) ||
        author.country.toLowerCase().contains(search);
  }

  @override
  int compare(Author a, Author b, String field) {
    return switch (field) {
      'birthYear' => a.birthYear.compareTo(b.birthYear),
      'country' => a.country.toLowerCase().compareTo(b.country.toLowerCase()),
      _ => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    };
  }
}
