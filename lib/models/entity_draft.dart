import 'author.dart';
import 'book.dart';
import 'catalog_entity.dart';
import 'genre.dart';
import 'json_values.dart';
import 'publisher.dart';
import 'reader.dart';
import '../validation/validators.dart';

Map<String, dynamic> entityDraft(CatalogEntity entity) {
  final values = entity.toJson();
  if (entity is Book) {
    values['_borrowed'] = entity.copiesTotal - entity.copiesAvailable;
  } else if (entity is Reader) {
    values['card.number'] = entity.card.number;
    values['card.issuedAt'] = Validators.dateText(entity.card.issuedAt);
    values['card.expiresAt'] = Validators.dateText(entity.card.expiresAt);
    values.remove('card');
  }
  return values;
}

CatalogEntity entityFromDraft(
  String section,
  Map<String, dynamic> values, {
  CatalogEntity? original,
}) {
  String text(String key) => Validators.text(values[key]);
  int number(String key) => JsonValues.integer(values[key]);
  final id = original?.id ?? 0;
  final deleted = original?.deletedAt;
  return switch (section) {
    'books' => Book(
      id: id,
      title: text('title'),
      isbn: text('isbn'),
      year: number('year'),
      pages: number('pages'),
      publisherId: number('publisherId'),
      authorIds: JsonValues.ids(values['authorIds']),
      genreIds: JsonValues.ids(values['genreIds']),
      copiesTotal: number('copiesTotal'),
      copiesAvailable: number('copiesTotal') - number('_borrowed'),
      createdAt: original is Book ? original.createdAt : DateTime.now().toUtc(),
      deletedAt: deleted,
    ),
    'authors' => Author(
      id: id,
      fullName: text('fullName'),
      birthYear: number('birthYear'),
      country: text('country'),
      deletedAt: deleted,
    ),
    'genres' => Genre(
      id: id,
      name: text('name'),
      description: text('description'),
      deletedAt: deleted,
    ),
    'publishers' => Publisher(
      id: id,
      name: text('name'),
      city: text('city'),
      foundedYear: number('foundedYear'),
      deletedAt: deleted,
    ),
    _ => Reader(
      id: id,
      fullName: text('fullName'),
      email: text('email').toLowerCase(),
      phone: text('phone'),
      deletedAt: deleted,
      card: LibraryCard(
        id: original is Reader ? original.card.id : 0,
        number: text('card.number').toUpperCase(),
        issuedAt: Validators.parseDate(values['card.issuedAt']),
        expiresAt: Validators.parseDate(values['card.expiresAt']),
      ),
    ),
  };
}
