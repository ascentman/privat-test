import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_failure_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/movie_details_result.dart';
import '../../domain/entities/movie_search_result.dart';
import '../../domain/repositories/movie_repository.dart';
import '../datasources/movie_local_data_source.dart';
import '../datasources/movie_remote_data_source.dart';
import '../models/movie_model.dart';

/// Remote-first repository: every call hits TMDB, stores what it gets, and
/// only reads the sqflite cache when the network call fails.
@LazySingleton(as: MovieRepository)
class MovieRepositoryImpl implements MovieRepository {
  const MovieRepositoryImpl(this._remote, this._local);

  final MovieRemoteDataSource _remote;
  final MovieLocalDataSource _local;

  @override
  Future<Result<MovieSearchResult>> searchMovies(
    String query, {
    int page = 1,
  }) async {
    final cacheKey = _cacheKey(query);
    try {
      final response = await _remote.searchMovies(query, page: page);
      // A failing cache write must not fail an otherwise good response.
      await _tryCache(
        () => _local.cacheSearchResults(
          cacheKey,
          response.results,
          page: page,
          totalResults: response.totalResults,
        ),
      );
      return Result.ok(
        MovieSearchResult(
          movies: _toEntities(response.results),
          totalResults: response.totalResults,
          page: response.page,
          totalPages: response.totalPages,
        ),
      );
    } on DioException catch (error) {
      final failure = mapDioException(error);
      // Only the first page may be answered from cache: the cache returns
      // everything it holds for the query, and appending that to what is
      // already on screen would show every row twice.
      if (page > 1) {
        return Result.err(failure);
      }
      return _searchFromCache(cacheKey, failure);
    } catch (error) {
      // Deserialisation runs after Dio has already returned, so a response
      // that parses as JSON but not as our model throws a plain TypeError.
      // Uncaught, it would escape into the bloc, which reports errors without
      // emitting — leaving the screen on its spinner with no way out.
      return Result.err(Failure.unexpected(error.toString()));
    }
  }

  @override
  Future<Result<MovieDetailsResult>> getMovieDetails(int id) async {
    try {
      final model = await _remote.getMovieDetails(id);
      await _tryCache(() => _local.cacheMovie(model));
      return Result.ok(MovieDetailsResult(movie: model.toEntity()));
    } on DioException catch (error) {
      final failure = mapDioException(error);
      if (!isRecoverableFromCache(failure)) {
        return Result.err(failure);
      }
      try {
        final cached = await _local.getCachedMovie(id);
        return Result.ok(
          MovieDetailsResult(movie: cached.toEntity(), fromCache: true),
        );
      } on CacheException {
        return Result.err(failure);
      }
    } catch (error) {
      // See searchMovies: a model-shape mismatch is not a DioException.
      return Result.err(Failure.unexpected(error.toString()));
    }
  }

  Future<Result<MovieSearchResult>> _searchFromCache(
    String cacheKey,
    Failure failure,
  ) async {
    if (!isRecoverableFromCache(failure)) {
      return Result.err(failure);
    }
    try {
      final cached = await _local.getCachedSearch(cacheKey);
      // A cached empty result is still an answer: the query genuinely matched
      // nothing, and saying so beats claiming to be offline.
      if (cached == null) {
        return Result.err(failure);
      }
      return Result.ok(
        MovieSearchResult(
          movies: _toEntities(cached.movies),
          fromCache: true,
          // The total the source reported when this was stored, so an offline
          // answer still admits it is only the first page of many.
          totalResults: cached.totalResults,
        ),
      );
    } on CacheException {
      return Result.err(failure);
    }
  }

  Future<void> _tryCache(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      // Caching is an optimisation; losing it must not break the request.
      // Deliberately broader than CacheException: with the catch-all below
      // turning stray errors into failures, a narrower catch here would let a
      // bad cache write sink an otherwise good response.
    }
  }

  List<Movie> _toEntities(List<MovieModel> models) =>
      models.map((model) => model.toEntity()).toList();

  /// Queries are normalised so `Black Adam`, `black adam ` and `BLACK ADAM`
  /// share one cache entry.
  String _cacheKey(String query) => query.trim().toLowerCase();
}
