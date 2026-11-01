import '../models/author.dart';
import '../models/book.dart';
import '../models/book_query.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';

abstract interface class EntityRepository<T, Q extends ListQuery> {
  int get revision;
  Future<List<T>> all({bool includeDeleted = false});
  Future<PageResult<T>> find(Q query);
  Future<T?> findById(int id);
  Future<T> create(T item);
  Future<T> update(T item);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}

abstract interface class BookRepository
    implements EntityRepository<Book, BookQuery> {}

abstract interface class AuthorRepository
    implements EntityRepository<Author, ListQuery> {}
