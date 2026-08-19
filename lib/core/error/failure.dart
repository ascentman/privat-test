import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// Domain-level error. Data-layer exceptions (Dio, sqflite) are translated
/// into one of these by the repository, so nothing above the data layer has
/// to know about transport details.
@freezed
sealed class Failure with _$Failure {
  const Failure._();

  /// No connectivity, timeout, or the host could not be reached.
  const factory Failure.network() = NetworkFailure;

  /// The API answered with a non-2xx status.
  const factory Failure.server({int? statusCode, String? message}) =
      ServerFailure;

  /// Reading from or writing to the local sqflite cache failed.
  const factory Failure.cache([String? message]) = CacheFailure;

  /// The search query is shorter than the required minimum.
  const factory Failure.queryTooShort(int minLength) = QueryTooShortFailure;

  /// The requested movie does not exist remotely and is not cached.
  const factory Failure.notFound() = NotFoundFailure;

  /// Message safe to render in the UI.
  String get userMessage => switch (this) {
    NetworkFailure() =>
      'No internet connection and nothing cached for this request.',
    ServerFailure(:final statusCode, :final message) =>
      message ?? 'The movie service failed (${statusCode ?? 'unknown'}).',
    CacheFailure(:final message) => message ?? 'Local cache is unavailable.',
    QueryTooShortFailure(:final minLength) =>
      'Type at least $minLength characters to search.',
    NotFoundFailure() => 'Movie not found.',
  };
}
