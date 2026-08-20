import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/result.dart';
import '../../../domain/entities/movie.dart';
import '../../../domain/usecases/get_movie_details.dart';

part 'movie_details_bloc.freezed.dart';
part 'movie_details_event.dart';
part 'movie_details_state.dart';

/// Drives the details screen.
///
/// It always loads by id rather than trusting a movie handed over by the
/// list screen — that is what makes a cold-start deep link
/// (`privattest://movie/436270`) render a complete screen.
@injectable
class MovieDetailsBloc extends Bloc<MovieDetailsEvent, MovieDetailsState> {
  MovieDetailsBloc(this._getMovieDetails)
    : super(const MovieDetailsState.loading()) {
    on<DetailsRequested>(_onRequested, transformer: restartable());
  }

  final GetMovieDetails _getMovieDetails;

  /// The last movie successfully shown, kept across retries: the widget only
  /// knows the one the list handed it, which a deep link never provides.
  Movie? _lastLoaded;

  Future<void> _onRequested(
    DetailsRequested event,
    Emitter<MovieDetailsState> emit,
  ) async {
    // Keep whatever is already on screen while refreshing. The test is
    // "is there a movie to show", not "did the last attempt succeed": a
    // failure carries the last loaded movie too, so a second retry from a
    // failed one must not blank the screen either.
    final showingAMovie = switch (state) {
      DetailsLoaded() => true,
      DetailsFailure(:final movie) => movie != null,
      DetailsLoading() => false,
    };
    if (!showingAMovie) {
      emit(const MovieDetailsState.loading());
    }
    final result = await _getMovieDetails(event.id);
    if (emit.isDone) {
      // Superseded by a newer request. `restartable()` only silences this
      // handler's emits; the body runs on, and without this an older response
      // would still overwrite _lastLoaded.
      return;
    }
    switch (result) {
      case Ok(:final value):
        _lastLoaded = value.movie;
        emit(MovieDetailsState.loaded(value.movie, fromCache: value.fromCache));
      case Err(:final failure):
        emit(MovieDetailsState.failure(failure, movie: _lastLoaded));
    }
  }
}
