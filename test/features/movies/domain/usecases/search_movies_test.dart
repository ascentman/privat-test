import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:privat_test/core/error/failure.dart';
import 'package:privat_test/core/utils/result.dart';
import 'package:privat_test/features/movies/domain/entities/movie_search_result.dart';
import 'package:privat_test/features/movies/domain/repositories/movie_repository.dart';
import 'package:privat_test/features/movies/domain/usecases/search_movies.dart';

import '../../../../helpers/test_data.dart';

class _MockMovieRepository extends Mock implements MovieRepository {}

void main() {
  late _MockMovieRepository repository;
  late SearchMovies useCase;

  setUp(() {
    repository = _MockMovieRepository();
    useCase = SearchMovies(repository);
  });

  test('rejects queries shorter than the minimum without hitting the repository', () async {
    final result = await useCase('b');

    expect(
      result,
      const Result<MovieSearchResult>.err(
        Failure.queryTooShort(SearchMovies.minQueryLength),
      ),
    );
    verifyZeroInteractions(repository);
  });

  test('treats a whitespace-padded short query as too short', () async {
    final result = await useCase('  b  ');

    expect(result.isOk, isFalse);
    verifyZeroInteractions(repository);
  });

  test('trims the query before delegating to the repository', () async {
    when(() => repository.searchMovies(any())).thenAnswer(
      (_) async => Result.ok(MovieSearchResult(movies: [tBlackAdam])),
    );

    final result = await useCase('  black adam  ');

    expect(result, Result.ok(MovieSearchResult(movies: [tBlackAdam])));
    verify(() => repository.searchMovies('black adam')).called(1);
  });
}
