import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../models/book_query.dart';
import '../state/book_list_notifier.dart';
import '../state/catalog_references.dart';
import '../state/entity_detail_notifier.dart';
import 'entity_detail_screen.dart';
import 'package:go_router/go_router.dart';
import '../repositories/library_repositories.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.id, this.back});
  final int id;
  final String? back;
  @override
  Widget build(BuildContext context) {
    final refs = context.watch<CatalogReferences>();
    return EntityDetailScreen<Book, BookQuery>(
      id: id,
      back: back,
      section: 'books',
      controller: context.read<BookDetailNotifier>(),
      listController: context.read<BookListNotifier>(),
      titleOf: (book) => book.title,
      extraActions:
          !context.watch<AuthNotifier>().allows(Permission.issue) ||
              context.read<LibraryRepositories>().loans == null
          ? null
          : FilledButton.icon(
              onPressed: () => context.go('/books/$id/issue'),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Выдать книгу'),
            ),
      fields: (book) => {
        'ID': book.id.toString(),
        'ISBN': book.isbn,
        'Год издания': book.year.toString(),
        'Количество страниц': book.pages.toString(),
        'Издательство': refs.publisherName(book.publisherId),
        'Авторы': book.authorIds.map(refs.authorName).join(', '),
        'Жанры': book.genreIds.map(refs.genreName).join(', '),
        'Экземпляров всего': book.copiesTotal.toString(),
        'Доступно': book.copiesAvailable.toString(),
      },
    );
  }
}
