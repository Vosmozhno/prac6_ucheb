abstract final class JsonValues {
  static int integer(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return value is String ? int.tryParse(value.trim()) ?? fallback : fallback;
  }

  static String string(Object? value, [String fallback = '']) =>
      value is String ? value : fallback;

  static DateTime? date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static Map<String, dynamic> map(Object? value) => value is Map
      ? {
          for (final entry in value.entries)
            if (entry.key is String) entry.key as String: entry.value,
        }
      : {};

  static List<int> ids(Object? value) {
    if (value is! List) return [];
    return value
        .map((item) => integer(item is Map ? item['id'] : item))
        .where((id) => id > 0)
        .toSet()
        .toList();
  }
}
