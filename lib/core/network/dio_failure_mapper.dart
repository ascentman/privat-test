import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Translates a transport-level [DioException] into a domain [Failure].
///
/// Connectivity-ish errors map to [NetworkFailure], which is the signal the
/// repository uses to decide whether falling back to the cache makes sense.
Failure mapDioException(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.cancel:
      return const Failure.network();
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return const Failure.network();
    case DioExceptionType.badResponse:
      final statusCode = exception.response?.statusCode;
      if (statusCode == 404) {
        return const Failure.notFound();
      }
      final data = exception.response?.data;
      final message = data is Map<String, dynamic>
          ? data['status_message'] as String?
          : null;
      return Failure.server(statusCode: statusCode, message: message);
  }
}

/// Whether the cache should be consulted after this failure.
bool isRecoverableFromCache(Failure failure) => switch (failure) {
  NetworkFailure() || ServerFailure() => true,
  CacheFailure() || QueryTooShortFailure() || NotFoundFailure() => false,
};
