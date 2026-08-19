import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:privat_test/core/error/exceptions.dart';
import 'package:privat_test/core/error/failure.dart';
import 'package:privat_test/core/utils/result.dart';
import 'package:privat_test/features/movies/data/datasources/movie_local_data_source.dart';
import 'package:privat_test/features/movies/data/datasources/movie_remote_data_source.dart';
import 'package:privat_test/features/movies/data/models/movie_search_response.dart';
import 'package:privat_test/features/movies/data/repositories/movie_repository_impl.dart';

import '../../../../helpers/test_data.dart';

class _MockRemote extends Mock implements MovieRemoteDataSource {}

class _MockLocal extends Mock implements MovieLocalDataSource {}

DioException _networkError() => DioException(
  requestOptions: RequestOptions(path: '/search/movie'),
  type: DioExceptionType.connectionError,
);

DioException _notFound() => DioException(
  requestOptions: RequestOptions(path: '/movie/1'),
  type: DioExceptionType.badResponse,
  response: Response<dynamic>(
    requestOptions: RequestOptions(path: '/movie/1'),
    statusCode: 404,
  ),
);

void main() {
  late _MockRemote remote;
  late _MockLocal local;
  late MovieRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(tBlackAdamModel);
  });

  setUp(() {
    remote = _MockRemote();
    local = _MockLocal();
    repository = MovieRepositoryImpl(remote, local);
  });

  group('searchMovies', () {
    test('returns remote results and caches them under a normalised key', () async {
      when(
        () => remote.searchMovies(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => const MovieSearchResponse(results: [tBlackAdamModel]),
      );
      when(
        () => local.cacheSearchResults(any(), any()),
      ).thenAnswer((_) async {});

      final result = await repository.searchMovies('Black Adam');

      expect(result.valueOrNull?.movies, [tBlackAdam]);
      expect(result.valueOrNull?.fromCache, isFalse);
      verify(
        () => local.cacheSearchResults('black adam', [tBlackAdamModel]),
      ).called(1);
    });

    test('still returns results when caching them fails', () async {
      when(
        () => remote.searchMovies(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => const MovieSearchResponse(results: [tBlackAdamModel]),
      );
      when(
        () => local.cacheSearchResults(any(), any()),
      ).thenThrow(const CacheException('disk full'));

      final result = await repository.searchMovies('black adam');

      expect(result.valueOrNull?.movies, [tBlackAdam]);
    });

    test('falls back to the cache when the network fails', () async {
      when(
        () => remote.searchMovies(any(), page: any(named: 'page')),
      ).thenThrow(_networkError());
      when(
        () => local.getCachedSearch('black adam'),
      ).thenAnswer((_) async => [tBlackAdamModel, tShazamModel]);

      final result = await repository.searchMovies('Black Adam');

      expect(result.valueOrNull?.movies, [tBlackAdam, tShazam]);
      expect(
        result.valueOrNull?.fromCache,
        isTrue,
        reason: 'the UI shows an offline banner based on this flag',
      );
    });

    test('surfaces the network failure when the query was never cached', () async {
      when(
        () => remote.searchMovies(any(), page: any(named: 'page')),
      ).thenThrow(_networkError());
      when(() => local.getCachedSearch(any())).thenAnswer((_) async => null);

      final result = await repository.searchMovies('black adam');

      expect(result, isA<Err<dynamic>>());
      expect((result as Err).failure, const Failure.network());
    });

    test('serves a cached empty result rather than claiming to be offline', () async {
      when(
        () => remote.searchMovies(any(), page: any(named: 'page')),
      ).thenThrow(_networkError());
      // Searched before, matched nothing — that is an answer, not ignorance.
      when(() => local.getCachedSearch(any())).thenAnswer((_) async => []);

      final result = await repository.searchMovies('zzzqqq');

      expect(result.valueOrNull?.movies, isEmpty);
      expect(result.valueOrNull?.fromCache, isTrue);
    });

    test('survives a cache write that fails in an unforeseen way', () async {
      when(
        () => remote.searchMovies(any(), page: any(named: 'page')),
      ).thenAnswer(
        (_) async => const MovieSearchResponse(results: [tBlackAdamModel]),
      );
      // Not a CacheException: caching is best-effort whatever goes wrong.
      when(() => local.cacheSearchResults(any(), any())).thenThrow(StateError('boom'));

      final result = await repository.searchMovies('black adam');

      expect(result.valueOrNull?.movies, [tBlackAdam]);
    });

    test('reports a response that does not match the model', () async {
      // Deserialisation happens after Dio returns, so this is a plain
      // TypeError rather than a DioException.
      when(
        () => remote.searchMovies(any(), page: any(named: 'page')),
      ).thenThrow(TypeError());

      final result = await repository.searchMovies('black adam');

      expect((result as Err).failure, isA<UnexpectedFailure>());
    });

    test('surfaces the network failure when the cache itself throws', () async {
      when(
        () => remote.searchMovies(any(), page: any(named: 'page')),
      ).thenThrow(_networkError());
      when(
        () => local.getCachedSearch(any()),
      ).thenThrow(const CacheException('corrupt'));

      final result = await repository.searchMovies('black adam');

      expect((result as Err).failure, const Failure.network());
    });
  });

  group('getMovieDetails', () {
    test('returns and caches the remote movie', () async {
      when(
        () => remote.getMovieDetails(436270),
      ).thenAnswer((_) async => tBlackAdamModel);
      when(() => local.cacheMovie(any())).thenAnswer((_) async {});

      final result = await repository.getMovieDetails(436270);

      expect(result.valueOrNull, tBlackAdam);
      verify(() => local.cacheMovie(tBlackAdamModel)).called(1);
    });

    test('falls back to the cached movie when the network fails', () async {
      when(() => remote.getMovieDetails(436270)).thenThrow(_networkError());
      when(
        () => local.getCachedMovie(436270),
      ).thenAnswer((_) async => tBlackAdamModel);

      final result = await repository.getMovieDetails(436270);

      expect(result.valueOrNull, tBlackAdam);
    });

    test('does not consult the cache for a 404', () async {
      when(() => remote.getMovieDetails(1)).thenThrow(_notFound());

      final result = await repository.getMovieDetails(1);

      expect((result as Err).failure, const Failure.notFound());
      verifyNever(() => local.getCachedMovie(any()));
    });

    test('reports a response that does not match the model', () async {
      when(() => remote.getMovieDetails(436270)).thenThrow(TypeError());

      final result = await repository.getMovieDetails(436270);

      expect((result as Err).failure, isA<UnexpectedFailure>());
      verifyNever(() => local.getCachedMovie(any()));
    });

    test('surfaces the failure on a cache miss', () async {
      when(() => remote.getMovieDetails(436270)).thenThrow(_networkError());
      when(
        () => local.getCachedMovie(436270),
      ).thenThrow(const CacheMissException());

      final result = await repository.getMovieDetails(436270);

      expect((result as Err).failure, const Failure.network());
    });
  });
}
