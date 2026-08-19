import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/exceptions.dart';
import '../models/movie_model.dart';

/// sqflite-backed cache of everything the app has already fetched.
abstract class MovieLocalDataSource {
  /// Stores [movies] and remembers that they were the answer to [query],
  /// preserving their order. [totalResults] is what the source said it had in
  /// total, which exceeds `movies.length` when the answer was one page of
  /// many.
  Future<void> cacheSearchResults(
    String query,
    List<MovieModel> movies, {
    int totalResults = 0,
  });

  /// Previously cached results for [query], in their original order.
  ///
  /// `null` when the query has never been searched, as opposed to an empty
  /// list for a query that was searched and legitimately matched nothing —
  /// offline, those two deserve different answers.
  Future<CachedSearch?> getCachedSearch(String query);

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
    List<MovieModel> movies, {
    int totalResults = 0,
  }) async {
    try {
      await _db.transaction((txn) async {
        final now = DateTime.now();
        for (final movie in movies) {
          await _upsertMovie(txn, movie, cachedAt: now);
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
        // Recorded even for an empty result set: that is the only way a later
        // offline search can tell "no matches" from "never looked".
        await txn.insert(AppDatabase.searchedQueriesTable, {
          AppDatabase.columnQuery: query,
          AppDatabase.columnCachedAt: now.millisecondsSinceEpoch,
          AppDatabase.columnTotalResults: totalResults,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } on DatabaseException catch (error) {
      throw CacheException(error.toString());
    }
  }

  @override
  Future<CachedSearch?> getCachedSearch(String query) async {
    try {
      final searched = await _db.query(
        AppDatabase.searchedQueriesTable,
        columns: [AppDatabase.columnTotalResults],
        where: '${AppDatabase.columnQuery} = ?',
        whereArgs: [query],
        limit: 1,
      );
      if (searched.isEmpty) {
        return null;
      }
      final totalResults =
          searched.first[AppDatabase.columnTotalResults] as int? ?? 0;
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
      return CachedSearch(
        movies: rows.map(MovieModel.fromDb).toList(),
        totalResults: totalResults,
      );
    } on DatabaseException catch (error) {
      throw CacheException(error.toString());
    }
  }

  @override
  Future<void> cacheMovie(MovieModel movie) async {
    try {
      await _upsertMovie(_db, movie);
    } on DatabaseException catch (error) {
      throw CacheException(error.toString());
    }
  }

  /// Writes a movie without ever deleting the existing row.
  ///
  /// `ConflictAlgorithm.replace` would be the obvious choice, but SQLite
  /// implements REPLACE as DELETE + INSERT, and that delete fires
  /// `ON DELETE CASCADE` just like an explicit one. Re-caching a movie would
  /// therefore drop its [AppDatabase.searchResultsTable] rows for *every*
  /// query, so opening a film's details would quietly evict it from the
  /// cached results of unrelated searches. An upsert updates in place and
  /// leaves the children alone.
  Future<void> _upsertMovie(
    DatabaseExecutor executor,
    MovieModel movie, {
    DateTime? cachedAt,
  }) {
    final row = movie.toDb(cachedAt: cachedAt);
    final columns = row.keys.join(', ');
    final placeholders = List.filled(row.length, '?').join(', ');
    final assignments = row.keys
        .where((column) => column != AppDatabase.columnId)
        .map((column) => '$column = excluded.$column')
        .join(', ');
    return executor.rawInsert(
      'INSERT INTO ${AppDatabase.moviesTable} ($columns) '
      'VALUES ($placeholders) '
      'ON CONFLICT(${AppDatabase.columnId}) DO UPDATE SET $assignments',
      row.values.toList(),
    );
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

/// What the cache knows about one past search: the stored movies, plus the
/// total the source reported at the time, so an offline answer can still say
/// it is only the first page of many.
class CachedSearch {
  const CachedSearch({required this.movies, required this.totalResults});

  final List<MovieModel> movies;
  final int totalResults;
}
