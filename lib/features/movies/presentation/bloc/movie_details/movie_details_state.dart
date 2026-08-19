part of 'movie_details_bloc.dart';

@freezed
sealed class MovieDetailsState with _$MovieDetailsState {
  const factory MovieDetailsState.loading() = DetailsLoading;

  const factory MovieDetailsState.loaded(Movie movie) = DetailsLoaded;

  const factory MovieDetailsState.failure(Failure failure, {int? movieId}) =
      DetailsFailure;
}
