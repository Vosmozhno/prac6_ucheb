import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:library_app/core/api_client.dart';
import 'package:library_app/models/library_snapshot.dart';

typedef FakeHandler = FutureOr<ResponseBody> Function(RequestOptions options);

class FakeApiAdapter implements HttpClientAdapter {
  FakeApiAdapter(this.handler);
  final FakeHandler handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody reply(Object? data, [int status = 200]) => ResponseBody.fromString(
  status == 204 ? '' : jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
ApiClient fakeClient(FakeApiAdapter adapter, {String? token}) {
  final dio = buildDio(
    baseUrl: 'http://example.test/api/',
    tokenProvider: () => token,
    logger: (_) {},
  );
  dio.httpClientAdapter = adapter;
  return ApiClient(dio, retryDelays: const [Duration.zero, Duration.zero]);
}

Map<String, dynamic> bookJson({int id = 1, String title = 'Книга API'}) {
  final json = LibrarySnapshot.seed().books.first.toJson();
  json['id'] = id;
  json['title'] = title;
  json.remove('publisherId');
  json.remove('authorIds');
  json.remove('genreIds');
  json['publisher'] = {'id': 1, 'name': 'АСТ'};
  json['authors'] = [
    {'id': 1, 'fullName': 'Толстой Л. Н.'},
  ];
  json['genres'] = [
    {'id': 1, 'name': 'Роман'},
  ];
  return json;
}

Map<String, dynamic> pageJson(
  List<Object?> items, {
  int page = 1,
  int size = 10,
  int? total,
}) => {
  'items': items,
  'page': page,
  'size': size,
  'total': total ?? items.length,
};
ResponseBody referencesReply(RequestOptions options) {
  final seed = LibrarySnapshot.seed();
  final section = options.path.split('/').last;
  return reply(
    pageJson((seed.sections[section] ?? []).map((e) => e.toJson()).toList()),
  );
}
