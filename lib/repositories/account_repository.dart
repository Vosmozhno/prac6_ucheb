import '../core/api_client.dart';
import '../models/json_values.dart';

class AccountRepository {
  AccountRepository(this.client);
  final ApiClient client;
  Future<Map<String, dynamic>> load(
    String section, {
    int page = 1,
    String search = '',
  }) async {
    final path = switch (section) {
      'users' => '/users',
      'stats' => '/stats',
      _ => '/loans',
    };
    return JsonValues.map(
      (await client.request(
        'GET',
        path,
        query: section == 'stats'
            ? null
            : {
                'page': page,
                'size': 10,
                'sort': section == 'users' ? 'username,asc' : 'issuedAt,desc',
                if (search.trim().isNotEmpty) 'search': search.trim(),
              },
      )).data,
    );
  }

  Future<void> changeRole(int id, String role) async {
    await client.request('PATCH', '/users/$id/role', data: {'role': role});
  }

  Future<void> renew(int id) async {
    await client.request('POST', '/loans/$id/renew');
  }

  Future<void> close(int id) async {
    await client.request('POST', '/loans/$id/return');
  }
}
