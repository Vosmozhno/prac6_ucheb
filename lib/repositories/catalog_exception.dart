class CatalogException implements Exception {
  const CatalogException(this.message, [this.fields = const {}]);
  final String message;
  final Map<String, String> fields;
  @override
  String toString() => message;
}
