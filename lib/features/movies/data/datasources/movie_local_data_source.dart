import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/exceptions.dart';
import '../models/movie_model.dart';

/// sqflite-backed cache of everything the app has already fetched.
abstract class MovieLocalDataSource {
  /// Stores [movies] and remembers that they were the answer to [query],
  /// preserving their order.
  Future<void> cacheSearchResults(String query, List<MovieModel> movies);

  /// Previously cached results for [query], in their original order.
  /// Empty when the query has never been searched.
  Future<List<MovieModel>> getCachedSearch(String query);

  Future<void> cacheMovie(MovieModel movie);

  /// Throws [CacheMissException] when the movie is not cached.
  Future<MovieModel> getCachedMovie(int id);
}

@LazySingleton(as: MovieLocalDataSource)
class MovieLocalDataSourceImpl implements MovieLocalDataSource {
  const MovieLocalDataSourceImpl(this._db);

  final Database _db;

  @override
  Future<void> cacheSearchResults(
    String query,
    List<MovieModel> movies,
  ) async {
    try {
      await _db.transaction((txn) async {
        final now = DateTime.now();
        for (final movie in movies) {
          await txn.insert(
            AppDatabase.moviesTable,
            movie.toDb(cachedAt: now),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        // Replace the whole result set for this query so removed hits do not
        // linger in the cache.
        await txn.delete(
          AppDatabase.searchResultsTable,
          where: '${AppDatabase.columnQuery} = ?',
          whereArgs: [query],
        );
        for (var position = 0; position < movies.length; position++) {
          await txn.insert(AppDatabase.searchResultsTable, {
            AppDatabase.columnQuery: query,
            AppDatabase.columnMovieId: movies[position].id,
            AppDatabase.columnPosition: position,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } on DatabaseException catch (error) {
      throw CacheException(error.toString());
    }
  }

  @override
  Future<List<MovieModel>> getCachedSearch(String query) async {
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT m.* FROM ${AppDatabase.moviesTable} m
        INNER JOIN ${AppDatabase.searchResultsTable} s
          ON s.${AppDatabase.columnMovieId} = m.${AppDatabase.columnId}
        WHERE s.${AppDatabase.columnQuery} = ?
        ORDER BY s.${AppDatabase.columnPosition} ASC
        ''',
        [query],
      );
      return rows.map(MovieModel.fromDb).toList();
    } on DatabaseException catch (error) {
      throw CacheException(error.toString());
    }
  }

  @override
  Future<void> cacheMovie(MovieModel movie) async {
    try {
      await _db.insert(
        AppDatabase.moviesTable,
        movie.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (error) {
      throw CacheException(error.toString());
    }
  }

  @override
  Future<MovieModel> getCachedMovie(int id) async {
    try {
      final rows = await _db.query(
        AppDatabase.moviesTable,
        where: '${AppDatabase.columnId} = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw CacheMissException('Movie $id is not cached');
      }
      return MovieModel.fromDb(rows.first);
    } on DatabaseException catch (error) {
      throw CacheException(error.toString());
    }
  }
}
