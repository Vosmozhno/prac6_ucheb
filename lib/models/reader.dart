import 'catalog_entity.dart';
import 'json_values.dart';

class LibraryCard {
  const LibraryCard({
    required this.id,
    required this.number,
    this.issuedAt,
    this.expiresAt,
  });
  final int id;
  final String number;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  LibraryCard copyWith({
    int? id,
    String? number,
    DateTime? issuedAt,
    DateTime? expiresAt,
  }) => LibraryCard(
    id: id ?? this.id,
    number: number ?? this.number,
    issuedAt: issuedAt ?? this.issuedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'issuedAt': issuedAt?.toUtc().toIso8601String(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };
  factory LibraryCard.fromJson(Map<String, dynamic> json) => LibraryCard(
    id: JsonValues.integer(json['id']),
    number: JsonValues.string(json['number']),
    issuedAt: JsonValues.date(json['issuedAt']),
    expiresAt: JsonValues.date(json['expiresAt']),
  );
}

class Reader implements CatalogEntity {
  const Reader({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.card,
    this.deletedAt,
  });
  @override
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final LibraryCard card;
  @override
  final DateTime? deletedAt;
  @override
  bool get isDeleted => deletedAt != null;
  Reader copyWith({
    int? id,
    String? fullName,
    String? email,
    String? phone,
    LibraryCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Reader(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    card: card ?? this.card,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'card': card.toJson(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
  factory Reader.fromJson(Map<String, dynamic> json) => Reader(
    id: JsonValues.integer(json['id']),
    fullName: JsonValues.string(json['fullName']),
    email: JsonValues.string(json['email']),
    phone: JsonValues.string(json['phone']),
    card: LibraryCard.fromJson(JsonValues.map(json['card'])),
    deletedAt: JsonValues.date(json['deletedAt']),
  );
}
