part of 'movie_search_bloc.dart';

@freezed
sealed class MovieSearchEvent with _$MovieSearchEvent {
  /// The user typed in the search field.
  const factory MovieSearchEvent.queryChanged(String query) = QueryChanged;

  /// The user tapped "Retry" after a failure.
  const factory MovieSearchEvent.retried() = Retried;
}
