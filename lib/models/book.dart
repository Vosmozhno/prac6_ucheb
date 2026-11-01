import 'catalog_entity.dart';
import 'json_values.dart';

class Book implements CatalogEntity {
  Book({
    required this.id,
    required this.title,
    required this.isbn,
    required this.year,
    required this.pages,
    required this.publisherId,
    required List<int> authorIds,
    required List<int> genreIds,
    required this.copiesTotal,
    required this.copiesAvailable,
    this.createdAt,
    this.deletedAt,
  }) : authorIds = List<int>.unmodifiable(authorIds),
       genreIds = List<int>.unmodifiable(genreIds);

  @override
  final int id;
  final String title;
  final String isbn;
  final int year;
  final int pages;
  final int publisherId;
  final List<int> authorIds;
  final List<int> genreIds;
  final int copiesTotal;
  final int copiesAvailable;
  final DateTime? createdAt;
  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isbn': isbn,
    'year': year,
    'pages': pages,
    'publisherId': publisherId,
    'authorIds': authorIds,
    'genreIds': genreIds,
    'copiesTotal': copiesTotal,
    'copiesAvailable': copiesAvailable,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: JsonValues.integer(json['id']),
    title: JsonValues.string(json['title']),
    isbn: JsonValues.string(json['isbn']),
    year: JsonValues.integer(json['year']),
    pages: JsonValues.integer(json['pages']),
    publisherId: JsonValues.integer(
      json['publisherId'] ?? JsonValues.map(json['publisher'])['id'],
    ),
    authorIds: JsonValues.ids(json['authorIds'] ?? json['authors']),
    genreIds: JsonValues.ids(json['genreIds'] ?? json['genres']),
    copiesTotal: JsonValues.integer(json['copiesTotal']),
    copiesAvailable: JsonValues.integer(json['copiesAvailable']),
    createdAt: JsonValues.date(json['createdAt']),
    deletedAt: JsonValues.date(json['deletedAt']),
  );

  Book copyWith({
    int? id,
    String? title,
    String? isbn,
    int? year,
    int? pages,
    int? publisherId,
    List<int>? authorIds,
    List<int>? genreIds,
    int? copiesTotal,
    int? copiesAvailable,
    DateTime? createdAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      isbn: isbn ?? this.isbn,
      year: year ?? this.year,
      pages: pages ?? this.pages,
      publisherId: publisherId ?? this.publisherId,
      authorIds: authorIds ?? this.authorIds,
      genreIds: genreIds ?? this.genreIds,
      copiesTotal: copiesTotal ?? this.copiesTotal,
      copiesAvailable: copiesAvailable ?? this.copiesAvailable,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
