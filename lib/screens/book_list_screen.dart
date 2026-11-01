import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/book_query.dart';
import '../state/book_list_notifier.dart';
import '../state/catalog_references.dart';
import '../widgets/book_filters.dart';
import '../widgets/entity_table.dart';
import 'catalog_screen.dart';

class BookListScreen extends StatelessWidget {
  const BookListScreen({super.key, required this.uri});
  final Uri uri;
  @override
  Widget build(BuildContext context) {
    final refs = context.watch<CatalogReferences>();
    return CatalogScreen<Book, BookQuery>(
      uri: uri,
      controller: context.read<BookListNotifier>(),
      parseQuery: BookQuery.fromParameters,
      path: '/books',
      section: 'books',
      title: 'Каталог книг',
      description:
          'Находите книги, управляйте записями и сохраняйте подборки по ссылке.',
      searchHint: 'Название или ISBN',
      titleOf: (book) => book.title,
      summary: (book) =>
          'ISBN: ${book.isbn}\nГод: ${book.year} · Страниц: ${book.pages}\n${refs.publisherName(book.publisherId)}\n${book.authorIds.map(refs.authorName).join(', ')}',
      filters: (query, onApply) => BookFilters(query: query, onApply: onApply),
      columns: (context, open) => [
        TableColumnSpec(
          label: 'Название',
          sortField: 'title',
          build: (book) => SizedBox(
            width: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: book.isDeleted ? null : () => open(book),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (book.isDeleted)
                  const Text(
                    'Удалено',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        TableColumnSpec(label: 'ISBN', build: (book) => Text(book.isbn)),
        TableColumnSpec(
          label: 'Год',
          sortField: 'year',
          numeric: true,
          build: (book) => Text(book.year.toString()),
        ),
        TableColumnSpec(
          label: 'Страниц',
          sortField: 'pages',
          numeric: true,
          build: (book) => Text(book.pages.toString()),
        ),
        TableColumnSpec(
          label: 'Издательство',
          build: (book) => Text(refs.publisherName(book.publisherId)),
        ),
        TableColumnSpec(
          label: 'В наличии',
          numeric: true,
          build: (book) =>
              Text('${book.copiesAvailable} / ${book.copiesTotal}'),
        ),
      ],
    );
  }
}
