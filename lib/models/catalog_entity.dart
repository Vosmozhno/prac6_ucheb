abstract interface class CatalogEntity {
  int get id;
  DateTime? get deletedAt;
  bool get isDeleted;
  Map<String, dynamic> toJson();
}

const catalogSections = ['books', 'authors', 'genres', 'publishers', 'readers'];
const sectionTitles = {
  'books': 'Книги',
  'authors': 'Авторы',
  'genres': 'Жанры',
  'publishers': 'Издательства',
  'readers': 'Читатели',
};
