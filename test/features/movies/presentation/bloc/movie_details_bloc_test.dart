import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:privat_test/core/error/failure.dart';
import 'package:privat_test/core/utils/result.dart';
import 'package:privat_test/features/movies/domain/entities/movie_details_result.dart';
import 'package:privat_test/features/movies/domain/usecases/get_movie_details.dart';
import 'package:privat_test/features/movies/presentation/bloc/movie_details/movie_details_bloc.dart';

import '../../../../helpers/test_data.dart';

class _MockGetMovieDetails extends Mock implements GetMovieDetails {}

void main() {
  late _MockGetMovieDetails getMovieDetails;

  setUp(() {
    getMovieDetails = _MockGetMovieDetails();
  });

  blocTest<MovieDetailsBloc, MovieDetailsState>(
    'loads the movie by id',
    setUp: () {
      when(() => getMovieDetails(any())).thenAnswer(
        (_) async => Result.ok(MovieDetailsResult(movie: tBlackAdam)),
      );
    },
    build: () => MovieDetailsBloc(getMovieDetails),
    act: (bloc) => bloc.add(MovieDetailsEvent.requested(tBlackAdam.id)),
    expect: () => [
      const MovieDetailsState.loading(),
      MovieDetailsState.loaded(tBlackAdam),
    ],
    verify: (_) => verify(() => getMovieDetails(tBlackAdam.id)).called(1),
  );

  blocTest<MovieDetailsBloc, MovieDetailsState>(
    'marks a movie that came from the cache',
    setUp: () {
      when(() => getMovieDetails(any())).thenAnswer(
        (_) async =>
            Result.ok(MovieDetailsResult(movie: tBlackAdam, fromCache: true)),
      );
    },
    build: () => MovieDetailsBloc(getMovieDetails),
    act: (bloc) => bloc.add(MovieDetailsEvent.requested(tBlackAdam.id)),
    expect: () => [
      const MovieDetailsState.loading(),
      MovieDetailsState.loaded(tBlackAdam, fromCache: true),
    ],
  );

  blocTest<MovieDetailsBloc, MovieDetailsState>(
    'carries the last loaded movie into a later failure',
    setUp: () {
      var call = 0;
      when(() => getMovieDetails(any())).thenAnswer((_) async {
        call++;
        return call == 1
            ? Result.ok(MovieDetailsResult(movie: tBlackAdam, fromCache: true))
            : const Result.err(Failure.unauthorized());
      });
    },
    build: () => MovieDetailsBloc(getMovieDetails),
    act: (bloc) async {
      bloc.add(MovieDetailsEvent.requested(tBlackAdam.id));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(MovieDetailsEvent.requested(tBlackAdam.id));
    },
    expect: () => [
      const MovieDetailsState.loading(),
      MovieDetailsState.loaded(tBlackAdam, fromCache: true),
      // No second loading: the movie already on screen stays put while the
      // retry runs.
      MovieDetailsState.failure(
        const Failure.unauthorized(),
        movie: tBlackAdam,
      ),
    ],
  );

  blocTest<MovieDetailsBloc, MovieDetailsState>(
    'a superseded response does not become the movie a later failure shows',
    setUp: () {
      var call = 0;
      when(() => getMovieDetails(any())).thenAnswer((_) async {
        call++;
        switch (call) {
          case 1:
            // Slow, and superseded before it lands.
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return Result.ok(
              MovieDetailsResult(
                movie: tBlackAdam.copyWith(title: 'Stale title'),
              ),
            );
          case 2:
            return Result.ok(MovieDetailsResult(movie: tBlackAdam));
          default:
            return const Result.err(Failure.network());
        }
      });
    },
    build: () => MovieDetailsBloc(getMovieDetails),
    act: (bloc) async {
      bloc.add(MovieDetailsEvent.requested(tBlackAdam.id));
      bloc.add(MovieDetailsEvent.requested(tBlackAdam.id));
      // Long enough for the superseded first response to arrive.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      bloc.add(MovieDetailsEvent.requested(tBlackAdam.id));
    },
    wait: const Duration(milliseconds: 100),
    verify: (bloc) {
      final state = bloc.state as DetailsFailure;
      expect(
        state.movie?.title,
        tBlackAdam.title,
        reason: 'the stale response must not have replaced what was shown',
      );
    },
  );

  blocTest<MovieDetailsBloc, MovieDetailsState>(
    'a second retry from a failure keeps the movie on screen',
    setUp: () {
      var call = 0;
      when(() => getMovieDetails(any())).thenAnswer((_) async {
        call++;
        return call == 1
            ? Result.ok(MovieDetailsResult(movie: tBlackAdam, fromCache: true))
            : const Result.err(Failure.network());
      });
    },
    build: () => MovieDetailsBloc(getMovieDetails),
    act: (bloc) async {
      bloc.add(MovieDetailsEvent.requested(tBlackAdam.id));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(MovieDetailsEvent.requested(tBlackAdam.id));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(MovieDetailsEvent.requested(tBlackAdam.id));
    },
    wait: const Duration(milliseconds: 50),
    expect: () => [
      const MovieDetailsState.loading(),
      MovieDetailsState.loaded(tBlackAdam, fromCache: true),
      MovieDetailsState.failure(const Failure.network(), movie: tBlackAdam),
      // Notably no second loading: a cold-start deep link has no movie to fall
      // back on, so emitting one here would blank the screen.
    ],
  );

  blocTest<MovieDetailsBloc, MovieDetailsState>(
    'reports a failure with no movie when nothing was ever loaded',
    setUp: () {
      when(() => getMovieDetails(any()))
          .thenAnswer((_) async => const Result.err(Failure.network()));
    },
    build: () => MovieDetailsBloc(getMovieDetails),
    act: (bloc) => bloc.add(MovieDetailsEvent.requested(tBlackAdam.id)),
    expect: () => [
      const MovieDetailsState.loading(),
      const MovieDetailsState.failure(Failure.network()),
    ],
  );
}
