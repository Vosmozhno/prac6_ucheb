import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/author.dart';
import '../models/list_query.dart';
import '../state/author_list_notifier.dart';
import '../state/catalog_references.dart';
import '../widgets/entity_filter_bar.dart';
import '../widgets/entity_table.dart';
import 'catalog_screen.dart';

class AuthorListScreen extends StatelessWidget {
  const AuthorListScreen({super.key, required this.uri});
  final Uri uri;
  @override
  Widget build(BuildContext context) => CatalogScreen<Author, ListQuery>(
    uri: uri,
    controller: context.read<AuthorListNotifier>(),
    parseQuery: ListQuery.fromParameters,
    path: '/authors',
    section: 'authors',
    title: 'Авторы',
    description: 'Справочник авторов: поиск по имени и стране.',
    searchHint: 'Фамилия, имя или страна',
    filters: (query, onApply) => EntityFilterBar(
      query: query,
      onApply: onApply,
      label: 'Страна',
      options: {
        for (final author in context.watch<CatalogReferences>().data.authors)
          if (!author.isDeleted) author.country: author.country,
      },
    ),
    titleOf: (author) => author.fullName,
    summary: (author) => 'Год рождения: ${author.birthYear}\n${author.country}',
    columns: (context, open) => [
      TableColumnSpec(
        label: 'ФИО',
        sortField: 'fullName',
        build: (author) => SizedBox(
          width: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: author.isDeleted ? null : () => open(author),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Text(
                  author.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (author.isDeleted)
                const Text(
                  'Удалено',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
      TableColumnSpec(
        label: 'Год рождения',
        sortField: 'birthYear',
        numeric: true,
        build: (author) => Text(author.birthYear.toString()),
      ),
      TableColumnSpec(
        label: 'Страна',
        sortField: 'country',
        build: (author) => Text(author.country),
      ),
    ],
  );
}
