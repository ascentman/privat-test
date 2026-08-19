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
      return const Failure.network();
    // A cancelled request is not a connectivity problem: it is what a
    // superseded request looks like. Folding it into NetworkFailure would make
    // the cache-fallback path claim the device is offline.
    case DioExceptionType.cancel:
      return const Failure.cancelled();
    // Not folded into NetworkFailure: answering a failed certificate check
    // with stale cached data and an "offline" message would hide it.
    case DioExceptionType.badCertificate:
      return const Failure.insecureConnection();
    // Dio's catch-all: it also wraps errors thrown by our own code. Reporting
    // those as "offline" would hide a defect behind stale cached data.
    case DioExceptionType.unknown:
      return Failure.unexpected(exception.message);
    case DioExceptionType.badResponse:
      final statusCode = exception.response?.statusCode;
      if (statusCode == 404) {
        return const Failure.notFound();
      }
      final data = exception.response?.data;
      // Not a cast: a proxy or a future API revision can put anything here, and
      // throwing inside the routine whose job is to make errors safe would
      // defeat the point.
      final message = data is Map<String, dynamic>
          ? data['status_message']?.toString()
          : null;
      // A rejected key is a configuration problem: retrying or answering from
      // cache would hide it behind stale results forever.
      if (statusCode == 401 || statusCode == 403) {
        return Failure.unauthorized(message);
      }
      return Failure.server(statusCode: statusCode, message: message);
  }
}

/// Whether the cache should be consulted after this failure.
bool isRecoverableFromCache(Failure failure) => switch (failure) {
  NetworkFailure() || ServerFailure() => true,
  CancelledFailure() ||
  InsecureConnectionFailure() ||
  UnauthorizedFailure() ||
  UnexpectedFailure() ||
  CacheFailure() ||
  QueryTooShortFailure() ||
  NotFoundFailure() => false,
};
