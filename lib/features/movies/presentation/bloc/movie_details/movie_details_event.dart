part of 'movie_details_bloc.dart';

@freezed
sealed class MovieDetailsEvent with _$MovieDetailsEvent {
  /// Load (or reload) the movie with this TMDB id.
  const factory MovieDetailsEvent.requested(int id) = DetailsRequested;
}
