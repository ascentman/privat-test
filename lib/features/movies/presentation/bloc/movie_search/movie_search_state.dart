part of 'movie_search_bloc.dart';

@freezed
sealed class MovieSearchState with _$MovieSearchState {
  /// Nothing searched yet, or the query is below the minimum length.
  const factory MovieSearchState.initial() = SearchInitial;

  const factory MovieSearchState.loading() = SearchLoading;

  /// [fromCache] is true when the network failed and sqflite answered instead.
  ///
  /// [query] is carried so a page arriving late can be checked against what
  /// the screen is showing now, and dropped if the user has moved on.
  const factory MovieSearchState.loaded({
    required List<Movie> movies,
    required String query,
    @Default(false) bool fromCache,

    /// Total matches reported by the source; see [MovieSearchResult].
    @Default(0) int totalResults,

    /// Highest page fetched so far.
    @Default(1) int page,

    /// Whether another page could be fetched.
    @Default(false) bool hasMore,

    /// Whether that fetch is in flight, so the list can show a footer spinner.
    @Default(false) bool isLoadingMore,
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
