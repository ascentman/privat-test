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

  Future<void> _onRequested(
    DetailsRequested event,
    Emitter<MovieDetailsState> emit,
  ) async {
    // Keep any optimistic movie on screen while refreshing.
    if (state is! DetailsLoaded) {
      emit(const MovieDetailsState.loading());
    }
    final result = await _getMovieDetails(event.id);
    switch (result) {
      case Ok(:final value):
        emit(MovieDetailsState.loaded(value));
      case Err(:final failure):
        emit(MovieDetailsState.failure(failure));
    }
  }
}
