import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_exceptions.dart';
import 'config.dart';

Dio buildDio({
  String baseUrl = apiBaseUrl,
  String? Function()? tokenProvider,
  void Function(String)? logger,
}) {
  final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final dio = Dio(
    BaseOptions(
      baseUrl: normalized,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  void log(String text) {
    if (kDebugMode) (logger ?? debugPrint)(text);
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        log('[API] → ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        log(
          '[API] ← ${response.requestOptions.method} ${response.requestOptions.uri} ${response.statusCode}',
        );
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        handler.next(response);
      },
      onError: (error, handler) {
        log(
          '[API] × ${error.requestOptions.method} ${error.requestOptions.uri} ${error.response?.statusCode ?? error.type.name}',
        );
        handler.next(error);
      },
    ),
  );
  return dio;
}

class ApiClient {
  ApiClient(
    this.dio, {
    this.retryDelays = const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
    ],
  });
  final Dio dio;
  final List<Duration> retryDelays;
  String? Function()? accessToken;
  Future<bool> Function(String? failedAccess)? onUnauthorized;
  Future<void> Function()? onSessionExpired;

  Future<Response<dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? query,
    Object? data,
    CancelToken? cancelToken,
  ) async {
    final sentToken = accessToken?.call();
    Future<Response<dynamic>> send() => guard(
      () => dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
        cancelToken: cancelToken,
      ),
    );
    try {
      return await send();
    } on UnauthorizedException {
      if (path.startsWith('/auth/') || onUnauthorized == null) rethrow;
      if (!await onUnauthorized!(sentToken)) rethrow;
      try {
        return await send();
      } on UnauthorizedException {
        await onSessionExpired?.call();
        rethrow;
      }
    }
  }

  Future<Response<dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    CancelToken? cancelToken,
  }) async {
    for (var attempt = 0; ; attempt++) {
      if (cancelToken?.isCancelled ?? false) {
        throw const RequestCancelledException();
      }
      try {
        return await _send(method, path, query, data, cancelToken);
      } on NetworkException {
        if (method != 'GET' || attempt >= 2 || attempt >= retryDelays.length) {
          rethrow;
        }
        final pause = Future<void>.delayed(retryDelays[attempt]);
        if (cancelToken == null) {
          await pause;
        } else {
          await Future.any<void>([
            pause,
            cancelToken.whenCancel.then<void>(
              (_) => throw const RequestCancelledException(),
            ),
          ]);
        }
      }
    }
  }
}
