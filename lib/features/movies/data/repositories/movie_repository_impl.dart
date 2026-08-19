import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/dio_failure_mapper.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/movie.dart';
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
  Future<Result<MovieSearchResult>> searchMovies(String query) async {
    final cacheKey = _cacheKey(query);
    try {
      final response = await _remote.searchMovies(query);
      // A failing cache write must not fail an otherwise good response.
      await _tryCache(() => _local.cacheSearchResults(cacheKey, response.results));
      return Result.ok(
        MovieSearchResult(movies: _toEntities(response.results)),
      );
    } on DioException catch (error) {
      return _searchFromCache(cacheKey, mapDioException(error));
    }
  }

  @override
  Future<Result<Movie>> getMovieDetails(int id) async {
    try {
      final model = await _remote.getMovieDetails(id);
      await _tryCache(() => _local.cacheMovie(model));
      return Result.ok(model.toEntity());
    } on DioException catch (error) {
      final failure = mapDioException(error);
      if (!isRecoverableFromCache(failure)) {
        return Result.err(failure);
      }
      try {
        final cached = await _local.getCachedMovie(id);
        return Result.ok(cached.toEntity());
      } on CacheException {
        return Result.err(failure);
      }
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
      if (cached.isEmpty) {
        return Result.err(failure);
      }
      return Result.ok(
        MovieSearchResult(movies: _toEntities(cached), fromCache: true),
      );
    } on CacheException {
      return Result.err(failure);
    }
  }

  Future<void> _tryCache(Future<void> Function() write) async {
    try {
      await write();
    } on CacheException {
      // Caching is an optimisation; losing it must not break the request.
    }
  }

  List<Movie> _toEntities(List<MovieModel> models) =>
      models.map((model) => model.toEntity()).toList();

  /// Queries are normalised so `Black Adam`, `black adam ` and `BLACK ADAM`
  /// share one cache entry.
  String _cacheKey(String query) => query.trim().toLowerCase();
}
