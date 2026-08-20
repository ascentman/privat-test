import 'package:freezed_annotation/freezed_annotation.dart';

import 'movie.dart';

part 'movie_search_result.freezed.dart';

/// Search results plus their provenance, so the UI can tell the user when it
/// is showing cached data instead of a fresh response.
@freezed
abstract class MovieSearchResult with _$MovieSearchResult {
  const factory MovieSearchResult({
    required List<Movie> movies,
    @Default(false) bool fromCache,

    /// How many matches the source reported in total. Larger than
    /// `movies.length` when the answer was truncated to one page, which the
    /// UI says out loud rather than silently showing a partial list.
    @Default(0) int totalResults,
  }) = _MovieSearchResult;
}
