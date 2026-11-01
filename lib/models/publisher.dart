import 'catalog_entity.dart';
import 'json_values.dart';

class Publisher implements CatalogEntity {
  const Publisher({
    required this.id,
    required this.name,
    required this.city,
    required this.foundedYear,
    this.deletedAt,
  });
  @override
  final int id;
  final String name;
  final String city;
  final int foundedYear;
  @override
  final DateTime? deletedAt;
  @override
  bool get isDeleted => deletedAt != null;
  Publisher copyWith({
    int? id,
    String? name,
    String? city,
    int? foundedYear,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Publisher(
    id: id ?? this.id,
    name: name ?? this.name,
    city: city ?? this.city,
    foundedYear: foundedYear ?? this.foundedYear,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'foundedYear': foundedYear,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
  factory Publisher.fromJson(Map<String, dynamic> json) => Publisher(
    id: JsonValues.integer(json['id']),
    name: JsonValues.string(json['name']),
    city: JsonValues.string(json['city']),
    foundedYear: JsonValues.integer(json['foundedYear']),
    deletedAt: JsonValues.date(json['deletedAt']),
  );
}
