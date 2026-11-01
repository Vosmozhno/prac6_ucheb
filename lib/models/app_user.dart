enum Role {
  reader('reader', 'Читатель'),
  librarian('librarian', 'Библиотекарь'),
  admin('admin', 'Администратор');

  const Role(this.value, this.label);
  final String value, label;
  static Role parse(Object? value) => values.firstWhere(
    (role) => role.value == value,
    orElse: () => Role.reader,
  );
}

enum Permission {
  catalog,
  manageCatalog,
  readers,
  issue,
  closeLoan,
  myLoans,
  renew,
  users,
  statistics,
  hardDelete,
  restore,
}

bool roleAllows(Role role, Permission permission) => switch (permission) {
  Permission.catalog => true,
  Permission.myLoans || Permission.renew => role == Role.reader,
  Permission.users ||
  Permission.statistics ||
  Permission.hardDelete ||
  Permission.restore => role == Role.admin,
  _ => role != Role.reader,
};

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });
  final int id;
  final String username, fullName;
  final Role role;
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: json['username'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    role: Role.parse(json['role']),
  );
  AppUser withRole(Role value) =>
      AppUser(id: id, username: username, fullName: fullName, role: value);
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role.value,
  };
}
