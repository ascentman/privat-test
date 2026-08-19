part of 'movie_details_bloc.dart';

@freezed
sealed class MovieDetailsState with _$MovieDetailsState {
  const factory MovieDetailsState.loading() = DetailsLoading;

  /// [fromCache] is true when the network failed and sqflite answered
  /// instead, so the screen can say the copy may be out of date.
  const factory MovieDetailsState.loaded(
    Movie movie, {
    @Default(false) bool fromCache,
  }) = DetailsLoaded;

  const factory MovieDetailsState.failure(Failure failure) = DetailsFailure;
}
