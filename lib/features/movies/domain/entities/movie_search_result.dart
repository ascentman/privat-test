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
  }) = _MovieSearchResult;
}
