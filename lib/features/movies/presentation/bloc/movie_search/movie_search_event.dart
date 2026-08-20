part of 'movie_search_bloc.dart';

@freezed
sealed class MovieSearchEvent with _$MovieSearchEvent {
  /// The user typed in the search field.
  const factory MovieSearchEvent.queryChanged(String query) = QueryChanged;

  /// The user tapped "Retry" after a failure.
  const factory MovieSearchEvent.retried() = Retried;

  /// The user emptied the field with the clear button. Separate from
  /// [QueryChanged] so it bypasses the debounce: an explicit clear should
  /// reset the screen at once, not 300ms later.
  const factory MovieSearchEvent.cleared() = Cleared;

  /// The list scrolled close enough to its end to want the next page.
  const factory MovieSearchEvent.loadMoreRequested() = LoadMoreRequested;
}
