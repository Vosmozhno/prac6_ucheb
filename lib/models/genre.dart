import 'catalog_entity.dart';
import 'json_values.dart';

class Genre implements CatalogEntity {
  const Genre({
    required this.id,
    required this.name,
    this.description = '',
    this.deletedAt,
  });
  @override
  final int id;
  final String name;
  final String description;
  @override
  final DateTime? deletedAt;
  @override
  bool get isDeleted => deletedAt != null;
  Genre copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Genre(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
    id: JsonValues.integer(json['id']),
    name: JsonValues.string(json['name']),
    description: JsonValues.string(json['description']),
    deletedAt: JsonValues.date(json['deletedAt']),
  );
}
