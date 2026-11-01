import '../models/book.dart';
import '../models/book_query.dart';
import '../repositories/entity_repository.dart';
import 'entity_list_notifier.dart';

class BookListNotifier extends EntityListNotifier<Book, BookQuery> {
  BookListNotifier(BookRepository super.repository, {super.beforeLoad})
    : super(
        initialQuery: const BookQuery(),
        idOf: (book) => book.id,
        isDeleted: (book) => book.isDeleted,
      );

  @override
  BookQuery updated({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    String? filter,
  }) => query.copyWith(
    search: search,
    sortField: sortField,
    sortAscending: sortAscending,
    page: page,
    size: size,
    includeDeleted: includeDeleted,
    filter: filter,
  );
}
