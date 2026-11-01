import '../models/author.dart';
import '../models/book.dart';
import '../models/catalog_entity.dart';
import '../models/entity_draft.dart';
import '../models/genre.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import '../validation/entity_validation.dart';
import 'catalog_exception.dart';
import 'entity_repository.dart';
import 'in_memory_author_repository.dart';
import 'in_memory_book_repository.dart';
import 'library_database.dart';
import 'reference_repositories.dart';
import '../core/api_client.dart';
import 'api_entity_repository.dart';
import 'api_reference_cache.dart';
import 'api_loan_repository.dart';
import '../models/list_query.dart';

class LibraryRepositories {
  LibraryRepositories(
    LibraryDatabase this.database, {
    BookRepository? books,
    AuthorRepository? authors,
  }) : books =
           books ??
           InMemoryBookRepository(backend: database.backend<Book>('books')),
       authors =
           authors ??
           InMemoryAuthorRepository(
             backend: database.backend<Author>('authors'),
           ),
       genres = GenreRepository(database),
       publishers = PublisherRepository(database),
       readers = ReaderRepository(database),
       remoteReferences = null,
       loans = null;

  factory LibraryRepositories.remote(
    ApiClient client,
    ApiReferenceCache cache,
  ) => LibraryRepositories._remote(client, cache, ApiRevision());
  LibraryRepositories._remote(
    ApiClient client,
    ApiReferenceCache cache,
    ApiRevision revision,
  ) : database = null,
      remoteReferences = cache,
      books = ApiBookRepository(client, changes: revision, references: cache),
      authors = ApiAuthorRepository(
        client,
        changes: revision,
        references: cache,
      ),
      genres = ApiEntityRepository<Genre, ListQuery>(
        client,
        'genres',
        Genre.fromJson,
        changes: revision,
        references: cache,
      ),
      publishers = ApiEntityRepository<Publisher, ListQuery>(
        client,
        'publishers',
        Publisher.fromJson,
        changes: revision,
        references: cache,
      ),
      readers = ApiEntityRepository<Reader, ListQuery>(
        client,
        'readers',
        Reader.fromJson,
        changes: revision,
        references: cache,
      ),
      loans = ApiLoanRepository(client, revision);
  final LibraryDatabase? database;
  final ApiReferenceCache? remoteReferences;
  final ApiLoanRepository? loans;
  bool get isRemote => remoteReferences != null;
  final BookRepository books;
  final AuthorRepository authors;
  final EntityRepository<Genre, ListQuery> genres;
  final EntityRepository<Publisher, ListQuery> publishers;
  final EntityRepository<Reader, ListQuery> readers;

  Future<CatalogEntity?> findById(String section, int id) => switch (section) {
    'books' => books.findById(id),
    'authors' => authors.findById(id),
    'genres' => genres.findById(id),
    'publishers' => publishers.findById(id),
    _ => readers.findById(id),
  };

  Map<String, String> validate(
    String section,
    Map<String, dynamic> draft, {
    int? id,
  }) => EntityValidation.validate(
    section,
    draft,
    database?.snapshot ?? remoteReferences!.snapshot,
    id: id,
    checkUniqueness: !isRemote,
  );

  Future<CatalogEntity> save(
    String section,
    Map<String, dynamic> values, {
    CatalogEntity? original,
  }) async {
    final errors = validate(section, values, id: original?.id);
    if (errors.isNotEmpty) {
      throw CatalogException('Проверьте поля формы.', errors);
    }
    final item = entityFromDraft(section, values, original: original);
    final creating = original == null;
    return switch (section) {
      'books' =>
        creating ? books.create(item as Book) : books.update(item as Book),
      'authors' =>
        creating
            ? authors.create(item as Author)
            : authors.update(item as Author),
      'genres' =>
        creating ? genres.create(item as Genre) : genres.update(item as Genre),
      'publishers' =>
        creating
            ? publishers.create(item as Publisher)
            : publishers.update(item as Publisher),
      _ =>
        creating
            ? readers.create(item as Reader)
            : readers.update(item as Reader),
    };
  }
}
