import 'catalog_entity.dart';
import 'json_values.dart';

class Author implements CatalogEntity {
  const Author({
    required this.id,
    required this.fullName,
    required this.birthYear,
    required this.country,
    this.deletedAt,
  });

  @override
  final int id;
  final String fullName;
  final int birthYear;
  final String country;
  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'birthYear': birthYear,
    'country': country,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  factory Author.fromJson(Map<String, dynamic> json) => Author(
    id: JsonValues.integer(json['id']),
    fullName: JsonValues.string(json['fullName']),
    birthYear: JsonValues.integer(json['birthYear']),
    country: JsonValues.string(json['country']),
    deletedAt: JsonValues.date(json['deletedAt']),
  );

  Author copyWith({
    int? id,
    String? fullName,
    int? birthYear,
    String? country,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Author(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      birthYear: birthYear ?? this.birthYear,
      country: country ?? this.country,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
