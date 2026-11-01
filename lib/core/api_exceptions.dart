import 'package:dio/dio.dart';
import '../repositories/catalog_exception.dart';

sealed class ApiException extends CatalogException {
  const ApiException(super.message, [super.fields]);
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message =
        'Нет соединения с сервером. Проверьте интернет и повторите запрос. После восстановления связи перезагрузка страницы не требуется.',
  ]);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    super.message = 'Для этого действия войдите в учебный API.',
  ]);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  const ConflictException(super.message);
}

class ValidationException extends ApiException {
  const ValidationException(super.message, super.fields);
  Map<String, String> get errors => fields;
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException() : super('Запрос отменён.');
}

class BadRequestException extends ApiException {
  const BadRequestException(super.message);
}

ApiException mapHttpError(int status, dynamic body) {
  final message = body is Map && body['message'] is String
      ? body['message'] as String
      : null;
  return switch (status) {
    400 => BadRequestException(message ?? 'Некорректный запрос.'),
    401 => const UnauthorizedException(),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
      message ?? 'Проверьте поля формы.',
      body is Map && body['errors'] is Map
          ? (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v'))
          : const {},
    ),
    _ => ServerException(message ?? 'Ошибка сервера (код $status).'),
  };
}

ApiException mapDioError(DioException error) {
  if (error.error is ApiException) return error.error as ApiException;
  if (error.response?.statusCode != null) {
    return mapHttpError(error.response!.statusCode!, error.response!.data);
  }
  return switch (error.type) {
    DioExceptionType.cancel => const RequestCancelledException(),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Сервер не ответил вовремя. Повторите запрос.',
    ),
    DioExceptionType.connectionError => const NetworkException(),
    _ => const ServerException('Не удалось обработать ответ API.'),
  };
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (error) {
    throw mapDioError(error);
  } on FormatException {
    throw const ServerException('Сервер вернул данные в неожиданном формате.');
  }
}
