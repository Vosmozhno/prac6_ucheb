enum CatalogFieldKind {
  text,
  integer,
  email,
  phone,
  date,
  publisher,
  authors,
  genres,
}

class CatalogFieldSpec {
  const CatalogFieldSpec(
    this.key,
    this.label, {
    this.kind = CatalogFieldKind.text,
    this.wide = false,
    this.lines = 1,
    this.group = '',
    this.hint,
  });
  final String key;
  final String label;
  final CatalogFieldKind kind;
  final bool wide;
  final int lines;
  final String group;
  final String? hint;
}

const catalogFormFields = <String, List<CatalogFieldSpec>>{
  'books': [
    CatalogFieldSpec('title', 'Название книги', wide: true),
    CatalogFieldSpec('isbn', 'ISBN', hint: '978-5-17-118366-4'),
    CatalogFieldSpec('year', 'Год издания', kind: CatalogFieldKind.integer),
    CatalogFieldSpec(
      'pages',
      'Количество страниц',
      kind: CatalogFieldKind.integer,
    ),
    CatalogFieldSpec(
      'copiesTotal',
      'Экземпляров всего',
      kind: CatalogFieldKind.integer,
    ),
    CatalogFieldSpec(
      'publisherId',
      'Издательство',
      kind: CatalogFieldKind.publisher,
      wide: true,
    ),
    CatalogFieldSpec(
      'authorIds',
      'Авторы',
      kind: CatalogFieldKind.authors,
      wide: true,
    ),
    CatalogFieldSpec(
      'genreIds',
      'Жанры',
      kind: CatalogFieldKind.genres,
      wide: true,
    ),
  ],
  'authors': [
    CatalogFieldSpec('fullName', 'ФИО автора', wide: true),
    CatalogFieldSpec(
      'birthYear',
      'Год рождения',
      kind: CatalogFieldKind.integer,
    ),
    CatalogFieldSpec('country', 'Страна'),
  ],
  'genres': [
    CatalogFieldSpec('name', 'Название жанра', wide: true),
    CatalogFieldSpec('description', 'Описание', wide: true, lines: 3),
  ],
  'publishers': [
    CatalogFieldSpec('name', 'Название издательства', wide: true),
    CatalogFieldSpec('city', 'Город'),
    CatalogFieldSpec(
      'foundedYear',
      'Год основания',
      kind: CatalogFieldKind.integer,
    ),
  ],
  'readers': [
    CatalogFieldSpec('fullName', 'ФИО читателя', wide: true),
    CatalogFieldSpec(
      'email',
      'Электронная почта',
      kind: CatalogFieldKind.email,
    ),
    CatalogFieldSpec(
      'phone',
      'Телефон',
      kind: CatalogFieldKind.phone,
      hint: '+7 900 000-00-00',
    ),
    CatalogFieldSpec(
      'card.number',
      'Номер билета',
      wide: true,
      group: 'Читательский билет',
    ),
    CatalogFieldSpec(
      'card.issuedAt',
      'Дата выдачи',
      kind: CatalogFieldKind.date,
      group: 'Читательский билет',
    ),
    CatalogFieldSpec(
      'card.expiresAt',
      'Действителен до',
      kind: CatalogFieldKind.date,
      group: 'Читательский билет',
    ),
  ],
};

const createFormTitles = {
  'books': 'Новая книга',
  'authors': 'Новый автор',
  'genres': 'Новый жанр',
  'publishers': 'Новое издательство',
  'readers': 'Новый читатель',
};
const editFormTitles = {
  'books': 'Редактирование книги',
  'authors': 'Редактирование автора',
  'genres': 'Редактирование жанра',
  'publishers': 'Редактирование издательства',
  'readers': 'Редактирование читателя',
};
