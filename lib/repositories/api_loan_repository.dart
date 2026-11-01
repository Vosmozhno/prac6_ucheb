import '../core/api_client.dart';
import 'package:dio/dio.dart';
import '../models/json_values.dart';
import '../models/reader.dart';
import 'api_entity_repository.dart';

class ApiLoanRepository {
  ApiLoanRepository(this.client, this.changes);
  final ApiClient client;
  final ApiRevision changes;
  CancelToken? _readersToken;
  void cancelReaderSearch() =>
      _readersToken?.cancel('Поиск читателя изменился');
  Future<List<Reader>> readers(String search) async {
    cancelReaderSearch();
    final token = _readersToken = CancelToken();
    final result = await client.request(
      'GET',
      '/readers',
      cancelToken: token,
      query: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': 1,
        'size': 10,
        'sort': 'fullName,asc',
      },
    );
    final json = JsonValues.map(result.data);
    return (json['items'] as List? ?? [])
        .map((raw) => Reader.fromJson(JsonValues.map(raw)))
        .toList();
  }

  Future<int> issue({
    required int bookId,
    required int readerId,
    required int days,
  }) async {
    final result = await client.request(
      'POST',
      '/loans',
      data: {'bookId': bookId, 'readerId': readerId, 'days': days},
    );
    changes.value++;
    return JsonValues.integer(JsonValues.map(result.data)['id']);
  }

  Future<void> returnLoan(int id) async {
    await client.request('POST', '/loans/$id/return');
    changes.value++;
  }
}
