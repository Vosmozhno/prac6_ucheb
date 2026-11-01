import '../models/genre.dart';
import '../models/list_query.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import 'entity_list_notifier.dart';

class ReferenceListNotifier<T> extends EntityListNotifier<T, ListQuery> {
  ReferenceListNotifier(
    super.repository, {
    required super.initialQuery,
    required super.idOf,
    required super.isDeleted,
    super.beforeLoad,
  });
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

class GenreListNotifier extends ReferenceListNotifier<Genre> {
  GenreListNotifier(super.repository, {super.beforeLoad})
    : super(
        initialQuery: const ListQuery(sortField: 'name'),
        idOf: (g) => g.id,
        isDeleted: (g) => g.isDeleted,
      );
}

class PublisherListNotifier extends ReferenceListNotifier<Publisher> {
  PublisherListNotifier(super.repository, {super.beforeLoad})
    : super(
        initialQuery: const ListQuery(sortField: 'name'),
        idOf: (p) => p.id,
        isDeleted: (p) => p.isDeleted,
      );
}

class ReaderListNotifier extends ReferenceListNotifier<Reader> {
  ReaderListNotifier(super.repository, {super.beforeLoad})
    : super(
        initialQuery: const ListQuery(),
        idOf: (r) => r.id,
        isDeleted: (r) => r.isDeleted,
      );
}
