import 'package:freezed_annotation/freezed_annotation.dart';

import 'movie.dart';

part 'movie_search_result.freezed.dart';

/// One page of search results, plus what the caller needs to decide whether to
/// ask for another.
@freezed
abstract class MovieSearchResult with _$MovieSearchResult {
  const MovieSearchResult._();

  const factory MovieSearchResult({
    required List<Movie> movies,

    /// True when the network failed and sqflite answered instead.
    @Default(false) bool fromCache,

    /// How many matches the source reported in total.
    @Default(0) int totalResults,

    /// Which page these movies came from, 1-based.
    @Default(1) int page,

    /// How many pages the source says it has.
    @Default(1) int totalPages,
  }) = _MovieSearchResult;

  /// Whether asking for another page could return anything.
  ///
  /// Never true for a cached answer: the cache holds what was fetched, and
  /// offline there is nowhere to fetch the rest from.
  bool get hasMore => !fromCache && page < totalPages;
}
