import 'list_query.dart';

class BookQuery extends ListQuery {
  const BookQuery({
    super.search = '',
    super.sortField = 'title',
    super.sortAscending = true,
    super.page = 1,
    super.size = 10,
    super.includeDeleted = false,
    super.filter,
    super.debugFail,
    super.debugDelay,
    this.genreId,
    this.publisherId,
    this.yearFrom,
    this.yearTo,
  });

  static const _unset = Object();

  final int? genreId;
  final int? publisherId;
  final int? yearFrom;
  final int? yearTo;

  factory BookQuery.fromParameters(Map<String, String> parameters) {
    final common = ListQuery.fromParameters(
      parameters,
      defaultSort: 'title',
      allowedSortFields: const {'title', 'year', 'pages'},
    );

    return BookQuery(
      search: common.search,
      sortField: common.sortField,
      sortAscending: common.sortAscending,
      page: common.page,
      size: common.size,
      includeDeleted: common.includeDeleted,
      debugFail: common.debugFail,
      debugDelay: common.debugDelay,
      genreId: ListQuery.positiveInt(parameters['genreId']),
      publisherId: ListQuery.positiveInt(parameters['publisherId']),
      yearFrom: ListQuery.positiveInt(parameters['yearFrom']),
      yearTo: ListQuery.positiveInt(parameters['yearTo']),
    );
  }

  @override
  BookQuery copyWith({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    String? filter,
    Object? debugFail = _unset,
    Object? debugDelay = _unset,
    Object? genreId = _unset,
    Object? publisherId = _unset,
    Object? yearFrom = _unset,
    Object? yearTo = _unset,
  }) {
    return BookQuery(
      search: search ?? this.search,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      filter: filter ?? this.filter,
      debugFail: identical(debugFail, _unset)
          ? this.debugFail
          : debugFail as int?,
      debugDelay: identical(debugDelay, _unset)
          ? this.debugDelay
          : debugDelay as int?,
      genreId: identical(genreId, _unset) ? this.genreId : genreId as int?,
      publisherId: identical(publisherId, _unset)
          ? this.publisherId
          : publisherId as int?,
      yearFrom: identical(yearFrom, _unset) ? this.yearFrom : yearFrom as int?,
      yearTo: identical(yearTo, _unset) ? this.yearTo : yearTo as int?,
    );
  }

  @override
  Map<String, String> toQueryParameters() {
    return {
      ...super.toQueryParameters(),
      if (genreId != null) 'genreId': '$genreId',
      if (publisherId != null) 'publisherId': '$publisherId',
      if (yearFrom != null) 'yearFrom': '$yearFrom',
      if (yearTo != null) 'yearTo': '$yearTo',
    };
  }
}
