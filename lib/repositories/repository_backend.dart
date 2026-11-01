abstract interface class RepositoryBackend<T> {
  List<T> get items;
  int get revision;
  Future<void> replace(List<T> items);
}
