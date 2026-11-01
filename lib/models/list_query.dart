class ListQuery {
  const ListQuery({
    this.search = '',
    this.sortField = 'fullName',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
    this.filter = '',
    this.debugFail,
    this.debugDelay,
  });

  static const _unset = Object();
  static const pageSizes = [10, 25, 50];

  final String search;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;
  final String filter;
  final int? debugFail;
  final int? debugDelay;

  factory ListQuery.fromParameters(
    Map<String, String> parameters, {
    String defaultSort = 'fullName',
    Set<String> allowedSortFields = const {'fullName', 'birthYear', 'country'},
  }) {
    final sort = (parameters['sort'] ?? '').split(',');
    final field = sort.first.trim();
    final requestedSize = int.tryParse(parameters['size'] ?? '') ?? 10;

    return ListQuery(
      search: parameters['search']?.trim() ?? '',
      sortField: allowedSortFields.contains(field) ? field : defaultSort,
      sortAscending: sort.length < 2 || sort[1].trim().toLowerCase() != 'desc',
      page: positiveInt(parameters['page']) ?? 1,
      size: pageSizes.contains(requestedSize) ? requestedSize : 10,
      includeDeleted: parameters['includeDeleted'] == 'true',
      filter: parameters['filter']?.trim() ?? '',
      debugFail: positiveInt(parameters['__fail']),
      debugDelay: positiveInt(parameters['__delay']),
    );
  }

  ListQuery copyWith({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    String? filter,
    Object? debugFail = _unset,
    Object? debugDelay = _unset,
  }) {
    return ListQuery(
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
    );
  }

  Map<String, String> toQueryParameters() {
    return {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
      'page': '$page',
      'size': '$size',
      if (includeDeleted) 'includeDeleted': 'true',
      if (filter.isNotEmpty) 'filter': filter,
      if (debugFail != null) '__fail': '$debugFail',
      if (debugDelay != null) '__delay': '$debugDelay',
    };
  }

  Uri toUri(String path) {
    return Uri(path: path, queryParameters: toQueryParameters());
  }

  static int? positiveInt(String? raw) {
    final value = int.tryParse(raw?.trim() ?? '');
    return value != null && value > 0 ? value : null;
  }
}
