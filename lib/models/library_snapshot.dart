import '../data/seed_data.dart';
import 'author.dart';
import 'book.dart';
import 'catalog_entity.dart';
import 'genre.dart';
import 'json_values.dart';
import 'publisher.dart';
import 'reader.dart';

class LibrarySnapshot {
  LibrarySnapshot(Map<String, List<CatalogEntity>> sections)
    : sections = Map.unmodifiable({
        for (final entry in sections.entries)
          entry.key: List<CatalogEntity>.unmodifiable(entry.value),
      });
  final Map<String, List<CatalogEntity>> sections;
  List<T> items<T extends CatalogEntity>(String section) =>
      List<T>.unmodifiable((sections[section] ?? []).cast<T>());
  List<Book> get books => items<Book>('books');
  List<Author> get authors => items<Author>('authors');
  List<Genre> get genres => items<Genre>('genres');
  List<Publisher> get publishers => items<Publisher>('publishers');
  List<Reader> get readers => items<Reader>('readers');
  LibrarySnapshot replace(String section, List<CatalogEntity> rows) =>
      LibrarySnapshot({...sections, section: rows});
  Map<String, dynamic> toJson() => {
    for (final section in catalogSections)
      section: (sections[section] ?? []).map((row) => row.toJson()).toList(),
  };

  factory LibrarySnapshot.fromJson(Map<String, dynamic> json) {
    final sections = <String, List<CatalogEntity>>{};
    for (final section in catalogSections) {
      final raw = json[section];
      if (raw is! List) {
        throw const FormatException('Отсутствует раздел каталога');
      }
      sections[section] = raw.map((row) {
        if (row is! Map) throw const FormatException('Некорректная запись');
        final data = JsonValues.map(row);
        return switch (section) {
          'books' => Book.fromJson(data),
          'authors' => Author.fromJson(data),
          'genres' => Genre.fromJson(data),
          'publishers' => Publisher.fromJson(data),
          _ => Reader.fromJson(data),
        };
      }).toList();
      final ids = sections[section]!.map((row) => row.id).toList();
      if (ids.any((id) => id < 1) || ids.toSet().length != ids.length) {
        throw const FormatException(
          'Повторяющиеся или отсутствующие идентификаторы',
        );
      }
    }
    final cardIds = sections['readers']!
        .cast<Reader>()
        .map((reader) => reader.card.id)
        .toList();
    if (cardIds.any((id) => id < 1) ||
        cardIds.toSet().length != cardIds.length) {
      throw const FormatException('Некорректная связь читателя и билета');
    }
    return LibrarySnapshot(sections);
  }

  factory LibrarySnapshot.seed() => LibrarySnapshot({
    'books': seedBooks
        .map(
          (book) => switch (book.id) {
            19 => book.copyWith(authorIds: [9]),
            20 => book.copyWith(authorIds: [10]),
            _ => book,
          },
        )
        .toList(),
    'authors': [
      ...seedAuthors,
      const Author(
        id: 9,
        fullName: 'Мартин Р.',
        birthYear: 1952,
        country: 'США',
      ),
      const Author(
        id: 10,
        fullName: 'Макконнелл С.',
        birthYear: 1962,
        country: 'США',
      ),
    ],
    'genres': [
      for (final entry in seedGenres.entries)
        Genre(
          id: entry.key,
          name: entry.value,
          description: 'Книги жанра «${entry.value}»',
        ),
    ],
    'publishers': [
      const Publisher(id: 1, name: 'АСТ', city: 'Москва', foundedYear: 1990),
      const Publisher(id: 2, name: 'Эксмо', city: 'Москва', foundedYear: 1991),
      const Publisher(
        id: 3,
        name: 'Азбука',
        city: 'Санкт-Петербург',
        foundedYear: 1995,
      ),
      const Publisher(
        id: 4,
        name: 'Питер',
        city: 'Санкт-Петербург',
        foundedYear: 1991,
      ),
    ],
    'readers': [
      for (var id = 1; id <= 12; id++)
        Reader(
          id: id,
          fullName: 'Читатель №$id',
          email: 'reader$id@example.test',
          phone: '+7 900 000 ${id.toString().padLeft(4, '0')}',
          card: LibraryCard(
            id: id,
            number: 'RC-${id.toString().padLeft(6, '0')}',
            issuedAt: DateTime.utc(2024, 1, 15),
            expiresAt: DateTime.utc(id % 4 == 0 ? 2025 : 2027, 1, 15),
          ),
        ),
    ],
  });
}
