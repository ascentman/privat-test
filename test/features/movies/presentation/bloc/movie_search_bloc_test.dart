import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:privat_test/core/error/failure.dart';
import 'package:privat_test/core/utils/result.dart';
import 'package:privat_test/features/movies/domain/entities/movie_search_result.dart';
import 'package:privat_test/features/movies/domain/usecases/search_movies.dart';
import 'package:privat_test/features/movies/presentation/bloc/movie_search/movie_search_bloc.dart';

import '../../../../helpers/test_data.dart';

class _MockSearchMovies extends Mock implements SearchMovies {}

/// Long enough for the bloc's debounce window to elapse.
const Duration _afterDebounce = Duration(milliseconds: 400);

void main() {
  late _MockSearchMovies searchMovies;

  setUp(() {
    searchMovies = _MockSearchMovies();
  });

  blocTest<MovieSearchBloc, MovieSearchState>(
    'emits loading then loaded for a successful search',
    setUp: () {
      when(() => searchMovies(any())).thenAnswer(
        (_) async => Result.ok(MovieSearchResult(movies: [tBlackAdam])),
      );
    },
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) => bloc.add(const MovieSearchEvent.queryChanged('black adam')),
    wait: _afterDebounce,
    expect: () => [
      const MovieSearchState.loading(),
      MovieSearchState.loaded(movies: [tBlackAdam]),
    ],
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'flags cached results so the UI can show the offline banner',
    setUp: () {
      when(() => searchMovies(any())).thenAnswer(
        (_) async =>
            Result.ok(MovieSearchResult(movies: [tBlackAdam], fromCache: true)),
      );
    },
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) => bloc.add(const MovieSearchEvent.queryChanged('black adam')),
    wait: _afterDebounce,
    expect: () => [
      const MovieSearchState.loading(),
      MovieSearchState.loaded(movies: [tBlackAdam], fromCache: true),
    ],
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'emits empty when the search matches nothing',
    setUp: () {
      when(() => searchMovies(any())).thenAnswer(
        (_) async => const Result.ok(MovieSearchResult(movies: [])),
      );
    },
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) => bloc.add(const MovieSearchEvent.queryChanged('zzzz')),
    wait: _afterDebounce,
    expect: () => [
      const MovieSearchState.loading(),
      const MovieSearchState.empty('zzzz'),
    ],
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'keeps the cached flag on an empty result',
    setUp: () {
      when(() => searchMovies(any())).thenAnswer(
        (_) async =>
            const Result.ok(MovieSearchResult(movies: [], fromCache: true)),
      );
    },
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) => bloc.add(const MovieSearchEvent.queryChanged('zzzz')),
    wait: _afterDebounce,
    expect: () => [
      const MovieSearchState.loading(),
      const MovieSearchState.empty('zzzz', fromCache: true),
    ],
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'emits failure when the search fails',
    setUp: () {
      when(
        () => searchMovies(any()),
      ).thenAnswer((_) async => const Result.err(Failure.network()));
    },
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) => bloc.add(const MovieSearchEvent.queryChanged('black adam')),
    wait: _afterDebounce,
    expect: () => [
      const MovieSearchState.loading(),
      const MovieSearchState.failure(Failure.network()),
    ],
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'returns to the prompt state for a query below the minimum length',
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) => bloc.add(const MovieSearchEvent.queryChanged('b')),
    wait: _afterDebounce,
    expect: () => [const MovieSearchState.initial()],
    verify: (_) => verifyNever(() => searchMovies(any())),
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'debounces keystrokes into a single search for the final query',
    setUp: () {
      when(() => searchMovies(any())).thenAnswer(
        (_) async => Result.ok(MovieSearchResult(movies: [tBlackAdam])),
      );
    },
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) async {
      bloc.add(const MovieSearchEvent.queryChanged('bl'));
      bloc.add(const MovieSearchEvent.queryChanged('bla'));
      bloc.add(const MovieSearchEvent.queryChanged('black adam'));
    },
    wait: _afterDebounce,
    expect: () => [
      const MovieSearchState.loading(),
      MovieSearchState.loaded(movies: [tBlackAdam]),
    ],
    verify: (_) {
      verify(() => searchMovies('black adam')).called(1);
      verifyNever(() => searchMovies('bl'));
      verifyNever(() => searchMovies('bla'));
    },
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'clearing resets the screen at once, without waiting for the debounce',
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) => bloc.add(const MovieSearchEvent.cleared()),
    wait: const Duration(milliseconds: 50),
    expect: () => [const MovieSearchState.initial()],
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'a search that resolves after a clear does not overwrite the screen',
    setUp: () {
      when(() => searchMovies(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return Result.ok(MovieSearchResult(movies: [tBlackAdam]));
      });
    },
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) async {
      bloc.add(const MovieSearchEvent.queryChanged('black adam'));
      // Let the debounce elapse so the request is genuinely in flight.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      bloc.add(const MovieSearchEvent.cleared());
    },
    wait: const Duration(milliseconds: 600),
    expect: () => [
      const MovieSearchState.loading(),
      const MovieSearchState.initial(),
    ],
  );

  blocTest<MovieSearchBloc, MovieSearchState>(
    'retries the last query',
    setUp: () {
      when(() => searchMovies(any())).thenAnswer(
        (_) async => Result.ok(MovieSearchResult(movies: [tBlackAdam])),
      );
    },
    build: () => MovieSearchBloc(searchMovies),
    act: (bloc) async {
      bloc.add(const MovieSearchEvent.queryChanged('black adam'));
      await Future<void>.delayed(_afterDebounce);
      bloc.add(const MovieSearchEvent.retried());
    },
    wait: _afterDebounce,
    verify: (_) => verify(() => searchMovies('black adam')).called(2),
  );
}
