import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the sqflite schema used to cache movies offline.
///
/// Two tables instead of one: [moviesTable] stores each movie exactly once,
/// while [searchResultsTable] maps a normalised query to the movie ids it
/// returned **and their order**, which a single denormalised table could not
/// preserve without duplicating movie rows per query.
abstract final class AppDatabase {
  static const String fileName = 'movies.db';
  static const int schemaVersion = 2;

  static const String moviesTable = 'movies';
  static const String searchResultsTable = 'search_results';

  /// Records that a query was actually run, which [searchResultsTable] alone
  /// cannot express: a search that legitimately matched nothing stores no
  /// rows there and would otherwise be indistinguishable from one that was
  /// never performed.
  static const String searchedQueriesTable = 'searched_queries';

  // movies columns
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnOverview = 'overview';
  static const String columnPosterPath = 'poster_path';
  static const String columnVoteAverage = 'vote_average';
  static const String columnReleaseDate = 'release_date';
  static const String columnCachedAt = 'cached_at';

  // search_results columns
  static const String columnQuery = 'query';
  static const String columnMovieId = 'movie_id';
  static const String columnPosition = 'position';

  /// Opens (and creates on first launch) the cache database.
  ///
  /// [path] is overridable so tests can point at an in-memory database.
  static Future<Database> open({String? path}) async {
    final databasePath = path ?? p.join(await getDatabasesPath(), fileName);
    return openDatabase(
      databasePath,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $moviesTable (
            $columnId INTEGER PRIMARY KEY,
            $columnTitle TEXT NOT NULL,
            $columnOverview TEXT NOT NULL,
            $columnPosterPath TEXT,
            $columnVoteAverage REAL NOT NULL DEFAULT 0,
            $columnReleaseDate TEXT,
            $columnCachedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $searchResultsTable (
            $columnQuery TEXT NOT NULL,
            $columnMovieId INTEGER NOT NULL,
            $columnPosition INTEGER NOT NULL,
            PRIMARY KEY ($columnQuery, $columnMovieId),
            FOREIGN KEY ($columnMovieId) REFERENCES $moviesTable ($columnId)
              ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_search_query ON $searchResultsTable ($columnQuery)',
        );
        await _createSearchedQueries(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createSearchedQueries(db);
          // Backfill from what v1 already cached. Without this every query an
          // existing install had stored would read as never searched, and its
          // offline results would sit in the database unreachable.
          await db.rawInsert(
            'INSERT OR IGNORE INTO $searchedQueriesTable '
            '($columnQuery, $columnCachedAt) '
            'SELECT DISTINCT $columnQuery, ? FROM $searchResultsTable',
            [DateTime.now().millisecondsSinceEpoch],
          );
        }
      },
    );
  }

  static Future<void> _createSearchedQueries(DatabaseExecutor db) => db.execute('''
    CREATE TABLE $searchedQueriesTable (
      $columnQuery TEXT PRIMARY KEY,
      $columnCachedAt INTEGER NOT NULL
    )
  ''');
}
