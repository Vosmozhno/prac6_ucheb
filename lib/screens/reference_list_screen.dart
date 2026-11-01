import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/genre.dart';
import '../models/list_query.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import '../state/catalog_references.dart';
import '../state/entity_list_notifier.dart';
import '../state/reference_list_notifier.dart';
import '../validation/validators.dart';
import '../widgets/entity_filter_bar.dart';
import '../widgets/entity_table.dart';
import 'catalog_screen.dart';

class ReferenceListScreen extends StatelessWidget {
  const ReferenceListScreen({
    super.key,
    required this.section,
    required this.uri,
  });
  final String section;
  final Uri uri;
  @override
  Widget build(BuildContext context) {
    final refs = context.watch<CatalogReferences>();
    return switch (section) {
      'genres' => _catalog<Genre>(
        controller: context.read<GenreListNotifier>(),
        title: 'Жанры',
        searchHint: 'Название или описание',
        sortFields: const {'name', 'description', 'id'},
        defaultSort: 'name',
        titleOf: (g) => g.name,
        summary: (g) => g.description,
        filterLabel: 'Связанные книги',
        filterOptions: const {'used': 'Есть книги', 'unused': 'Нет книг'},
        columns: (open) => [
          TableColumnSpec(
            label: 'Название',
            sortField: 'name',
            build: (g) => _title(g.name, g.isDeleted, () => open(g)),
          ),
          TableColumnSpec(
            label: 'Описание',
            sortField: 'description',
            build: (g) => SizedBox(
              width: 320,
              child: Text(
                g.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          TableColumnSpec(
            label: 'ID',
            sortField: 'id',
            numeric: true,
            build: (g) => Text(g.id.toString()),
          ),
        ],
      ),
      'publishers' => _catalog<Publisher>(
        controller: context.read<PublisherListNotifier>(),
        title: 'Издательства',
        searchHint: 'Название или город',
        sortFields: const {'name', 'city', 'foundedYear'},
        defaultSort: 'name',
        titleOf: (p) => p.name,
        summary: (p) => '${p.city}\nГод основания: ${p.foundedYear}',
        filterLabel: 'Город',
        filterOptions: {
          for (final p in refs.data.publishers)
            if (!p.isDeleted) p.city: p.city,
        },
        columns: (open) => [
          TableColumnSpec(
            label: 'Название',
            sortField: 'name',
            build: (p) => _title(p.name, p.isDeleted, () => open(p)),
          ),
          TableColumnSpec(
            label: 'Город',
            sortField: 'city',
            build: (p) => Text(p.city),
          ),
          TableColumnSpec(
            label: 'Год основания',
            sortField: 'foundedYear',
            numeric: true,
            build: (p) => Text(p.foundedYear.toString()),
          ),
        ],
      ),
      _ => _catalog<Reader>(
        controller: context.read<ReaderListNotifier>(),
        title: 'Читатели',
        searchHint: 'ФИО, почта, телефон или номер билета',
        sortFields: const {'fullName', 'email', 'expiresAt'},
        defaultSort: 'fullName',
        titleOf: (r) => r.fullName,
        summary: (r) =>
            '${r.email}\n${r.phone}\nБилет: ${r.card.number}\nДействителен до: ${Validators.dateText(r.card.expiresAt)}',
        filterLabel: 'Читательский билет',
        filterOptions: const {'valid': 'Действующий', 'expired': 'Истёк срок'},
        columns: (open) => [
          TableColumnSpec(
            label: 'ФИО',
            sortField: 'fullName',
            build: (r) => _title(r.fullName, r.isDeleted, () => open(r)),
          ),
          TableColumnSpec(
            label: 'Почта',
            sortField: 'email',
            build: (r) => Text(r.email),
          ),
          TableColumnSpec(label: 'Билет', build: (r) => Text(r.card.number)),
          TableColumnSpec(
            label: 'Действителен до',
            sortField: 'expiresAt',
            build: (r) => Text(Validators.dateText(r.card.expiresAt)),
          ),
        ],
      ),
    };
  }

  Widget _title(String name, bool deleted, VoidCallback open) => SizedBox(
    width: 240,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: deleted ? null : open,
          child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        if (deleted)
          const Text(
            'Удалено',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
      ],
    ),
  );

  Widget _catalog<T>({
    required EntityListNotifier<T, ListQuery> controller,
    required String title,
    required String searchHint,
    required Set<String> sortFields,
    required String defaultSort,
    required String Function(T) titleOf,
    required String Function(T) summary,
    required String filterLabel,
    required Map<String, String> filterOptions,
    required List<TableColumnSpec<T>> Function(ValueChanged<T>) columns,
  }) => CatalogScreen<T, ListQuery>(
    uri: uri,
    controller: controller,
    section: section,
    path: '/$section',
    title: title,
    description: 'Список записей: поиск, фильтрация и управление каталогом.',
    searchHint: searchHint,
    titleOf: titleOf,
    summary: summary,
    parseQuery: (parameters) => ListQuery.fromParameters(
      parameters,
      defaultSort: defaultSort,
      allowedSortFields: sortFields,
    ),
    filters: (query, apply) => EntityFilterBar(
      query: query,
      onApply: apply,
      label: filterLabel,
      options: filterOptions,
    ),
    columns: (context, open) => columns(open),
  );
}
