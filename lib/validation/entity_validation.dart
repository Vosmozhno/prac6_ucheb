import '../models/book.dart';
import '../models/json_values.dart';
import '../models/library_snapshot.dart';
import 'validators.dart';

abstract final class EntityValidation {
  static Map<String, String> validate(
    String section,
    Map<String, dynamic> values,
    LibrarySnapshot data, {
    int? id,
    bool checkUniqueness = true,
  }) {
    final errors = <String, String>{};
    void check(String key, String? message) {
      if (message != null) errors[key] = message;
    }

    String text(String key) => Validators.text(values[key]);
    final currentYear = DateTime.now().year;
    switch (section) {
      case 'books':
        check('title', Validators.requiredText(values['title'], max: 200));
        check('isbn', Validators.isbn(values['isbn']));
        check('year', Validators.integer(values['year'], max: currentYear));
        check('pages', Validators.integer(values['pages']));
        final borrowed = JsonValues.integer(values['_borrowed']);
        check(
          'copiesTotal',
          Validators.integer(
            values['copiesTotal'],
            min: borrowed > 1 ? borrowed : 1,
          ),
        );
        if (borrowed < 0) {
          errors['copiesTotal'] =
              'Доступных экземпляров не может быть больше общего количества';
        }
        final publisher = JsonValues.integer(values['publisherId']);
        if (!data.publishers.any((p) => p.id == publisher && !p.isDeleted)) {
          errors['publisherId'] = 'Выберите действующее издательство';
        }
        final authors = JsonValues.ids(values['authorIds']);
        final genres = JsonValues.ids(values['genreIds']);
        if (authors.isEmpty) {
          errors['authorIds'] = 'Выберите хотя бы одного автора';
        } else if (authors.any(
          (id) => !data.authors.any((a) => a.id == id && !a.isDeleted),
        )) {
          errors['authorIds'] = 'Выберите действующих авторов';
        }
        if (genres.isEmpty) {
          errors['genreIds'] = 'Выберите хотя бы один жанр';
        } else if (genres.any(
          (id) => !data.genres.any((g) => g.id == id && !g.isDeleted),
        )) {
          errors['genreIds'] = 'Выберите действующие жанры';
        }
        if (checkUniqueness &&
            !errors.containsKey('isbn') &&
            data.books.any(
              (b) =>
                  b.id != id &&
                  Validators.canonicalIsbn(b.isbn) ==
                      Validators.canonicalIsbn(text('isbn')),
            )) {
          errors['isbn'] = 'Книга с таким ISBN уже существует';
        }
      case 'authors':
        check(
          'fullName',
          Validators.requiredText(values['fullName'], min: 2, max: 150),
        );
        check(
          'birthYear',
          Validators.integer(values['birthYear'], max: currentYear),
        );
        check(
          'country',
          Validators.requiredText(values['country'], min: 2, max: 80),
        );
      case 'genres':
        check('name', Validators.requiredText(values['name'], min: 2, max: 80));
        check(
          'description',
          Validators.requiredText(
            values['description'],
            required: false,
            max: 500,
          ),
        );
        if (checkUniqueness &&
            data.genres.any(
              (g) =>
                  g.id != id &&
                  g.name.trim().toLowerCase() == text('name').toLowerCase(),
            )) {
          errors['name'] = 'Жанр с таким названием уже существует';
        }
      case 'publishers':
        check(
          'name',
          Validators.requiredText(values['name'], min: 2, max: 120),
        );
        check(
          'city',
          Validators.requiredText(values['city'], min: 2, max: 100),
        );
        check(
          'foundedYear',
          Validators.integer(values['foundedYear'], max: currentYear),
        );
        if (checkUniqueness &&
            data.publishers.any(
              (p) =>
                  p.id != id &&
                  p.name.trim().toLowerCase() == text('name').toLowerCase(),
            )) {
          errors['name'] = 'Издательство с таким названием уже существует';
        }
      case 'readers':
        check(
          'fullName',
          Validators.requiredText(values['fullName'], min: 2, max: 150),
        );
        check('email', Validators.email(values['email']));
        check('phone', Validators.phone(values['phone']));
        check(
          'card.number',
          Validators.requiredText(values['card.number'], min: 3, max: 32),
        );
        if (!errors.containsKey('card.number') &&
            !RegExp(
              r'^[A-Za-z0-9][A-Za-z0-9-]{2,31}$',
            ).hasMatch(text('card.number'))) {
          errors['card.number'] = 'Буквы латиницы, цифры и дефис';
        }
        check('card.issuedAt', Validators.date(values['card.issuedAt']));
        check('card.expiresAt', Validators.date(values['card.expiresAt']));
        final issued = Validators.parseDate(values['card.issuedAt']);
        final expires = Validators.parseDate(values['card.expiresAt']);
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);
        if (issued != null && issued.isAfter(today)) {
          errors['card.issuedAt'] = 'Дата выдачи не может быть в будущем';
        }
        if (issued != null && expires != null && !expires.isAfter(issued)) {
          errors['card.expiresAt'] =
              'Срок действия должен быть позже даты выдачи';
        }
        if (checkUniqueness &&
            !errors.containsKey('email') &&
            data.readers.any(
              (r) =>
                  r.id != id &&
                  r.email.trim().toLowerCase() == text('email').toLowerCase(),
            )) {
          errors['email'] = 'Читатель с такой почтой уже существует';
        }
        if (checkUniqueness &&
            !errors.containsKey('card.number') &&
            data.readers.any(
              (r) =>
                  r.id != id &&
                  r.card.number.toUpperCase() ==
                      text('card.number').toUpperCase(),
            )) {
          errors['card.number'] = 'Билет с таким номером уже существует';
        }
    }
    return errors;
  }

  static int linkedBooks(LibrarySnapshot data, String section, int id) => data
      .books
      .where(
        (Book b) => switch (section) {
          'publishers' => b.publisherId == id,
          'authors' => b.authorIds.contains(id),
          'genres' => b.genreIds.contains(id),
          _ => false,
        },
      )
      .length;
}
