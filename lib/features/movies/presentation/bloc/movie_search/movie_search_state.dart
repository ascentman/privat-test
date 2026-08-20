part of 'movie_search_bloc.dart';

@freezed
sealed class MovieSearchState with _$MovieSearchState {
  /// Nothing searched yet, or the query is below the minimum length.
  const factory MovieSearchState.initial() = SearchInitial;

  const factory MovieSearchState.loading() = SearchLoading;

  /// [fromCache] is true when the network failed and sqflite answered instead.
  const factory MovieSearchState.loaded({
    required List<Movie> movies,
    @Default(false) bool fromCache,

    /// Total matches reported by the source; see [MovieSearchResult].
    @Default(0) int totalResults,
  }) = SearchLoaded;

  /// The search succeeded but matched nothing.
  ///
  /// [fromCache] matters here as much as it does for results: "TMDB has no
  /// such film" and "you are offline and this is what we knew" are different
  /// answers to the user.
  const factory MovieSearchState.empty(
    String query, {
    @Default(false) bool fromCache,
  }) = SearchEmpty;

  const factory MovieSearchState.failure(Failure failure) = SearchFailure;
}
