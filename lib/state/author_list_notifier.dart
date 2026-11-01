import '../models/author.dart';
import '../models/list_query.dart';
import '../repositories/entity_repository.dart';
import 'entity_list_notifier.dart';

class AuthorListNotifier extends EntityListNotifier<Author, ListQuery> {
  AuthorListNotifier(AuthorRepository super.repository, {super.beforeLoad})
    : super(
        initialQuery: const ListQuery(),
        idOf: (author) => author.id,
        isDeleted: (author) => author.isDeleted,
      );

  @override
  ListQuery updated({
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
