import 'package:freezed_annotation/freezed_annotation.dart';

import 'movie.dart';

part 'movie_details_result.freezed.dart';

/// A movie plus where it came from.
///
/// The search screen has told the user when results are cached since the
/// start; details deserve the same honesty, or an offline screen reads as
/// current when its rating and description may be months old.
@freezed
abstract class MovieDetailsResult with _$MovieDetailsResult {
  const factory MovieDetailsResult({
    required Movie movie,
    @Default(false) bool fromCache,
  }) = _MovieDetailsResult;
}
