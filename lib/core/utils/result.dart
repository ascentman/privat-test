import 'package:freezed_annotation/freezed_annotation.dart';

import '../error/failure.dart';

part 'result.freezed.dart';

/// Either a success value or a [Failure].
///
/// Used instead of `dartz`/`fpdart`: Dart 3 pattern matching over a sealed
/// type gives the same exhaustiveness guarantees without the extra dependency.
///
/// ```dart
/// switch (result) {
///   Ok(:final value) => emit(Loaded(value)),
///   Err(:final failure) => emit(Error(failure)),
/// }
/// ```
@freezed
sealed class Result<T> with _$Result<T> {
  const Result._();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  /// The success value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };
}
