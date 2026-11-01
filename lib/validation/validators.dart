abstract final class Validators {
  static String text(Object? value) => value is String ? value.trim() : '';
  static String? requiredText(
    Object? value, {
    int min = 1,
    int max = 200,
    bool required = true,
  }) {
    final input = text(value);
    if (input.isEmpty) return required ? 'Обязательное поле' : null;
    if (input.length < min) return 'Не менее $min символов';
    if (input.length > max) return 'Не более $max символов';
    return null;
  }

  static int? parseInteger(Object? value) =>
      value is int ? value : int.tryParse(text(value));

  static String? integer(Object? value, {int min = 1, int max = 100000}) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Обязательное поле';
    }
    final number = parseInteger(value);
    if (number == null) return 'Введите целое число';
    return number < min || number > max ? 'Значение от $min до $max' : null;
  }

  static String canonicalIsbn(String value) =>
      value.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  static String? isbn(Object? value) {
    final error = requiredText(value, max: 25);
    if (error != null) return error;
    final input = canonicalIsbn(text(value));
    return RegExp(r'^(\d{13}|\d{9}[\dX])$').hasMatch(input)
        ? null
        : 'ISBN: 10 или 13 символов, допускаются пробелы и дефисы';
  }

  static String? email(Object? value) {
    final error = requiredText(value, max: 254);
    if (error != null) return error;
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text(value))
        ? null
        : 'Введите корректный адрес почты';
  }

  static String? phone(Object? value) {
    final error = requiredText(value, max: 30);
    if (error != null) return error;
    final input = text(value);
    final digits = input.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^\+?[\d ()-]+$').hasMatch(input) &&
            digits.length >= 10 &&
            digits.length <= 15
        ? null
        : 'Телефон: от 10 до 15 цифр';
  }

  static DateTime? parseDate(Object? value) {
    final input = text(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return null;
    final parsed = DateTime.tryParse(input);
    if (parsed == null || dateText(parsed) != input) return null;
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static String dateText(DateTime? date) =>
      date == null ? '' : date.toIso8601String().substring(0, 10);
  static String? date(Object? value) => text(value).isEmpty
      ? 'Обязательное поле'
      : parseDate(value) == null
      ? 'Дата в формате ГГГГ-ММ-ДД'
      : null;
}
