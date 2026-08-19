import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:privat_test/core/database/app_database.dart';
import 'package:privat_test/features/movies/data/datasources/movie_local_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_data.dart';

/// The v1 schema, kept verbatim so the upgrade path can be exercised against
/// what shipped rather than against today's `onCreate`.
Future<Database> _openV1(String path) => openDatabase(
  path,
  version: 1,
  onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
  onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE ${AppDatabase.moviesTable} (
        ${AppDatabase.columnId} INTEGER PRIMARY KEY,
        ${AppDatabase.columnTitle} TEXT NOT NULL,
        ${AppDatabase.columnOverview} TEXT NOT NULL,
        ${AppDatabase.columnPosterPath} TEXT,
        ${AppDatabase.columnVoteAverage} REAL NOT NULL DEFAULT 0,
        ${AppDatabase.columnReleaseDate} TEXT,
        ${AppDatabase.columnCachedAt} INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ${AppDatabase.searchResultsTable} (
        ${AppDatabase.columnQuery} TEXT NOT NULL,
        ${AppDatabase.columnMovieId} INTEGER NOT NULL,
        ${AppDatabase.columnPosition} INTEGER NOT NULL,
        PRIMARY KEY (${AppDatabase.columnQuery}, ${AppDatabase.columnMovieId}),
        FOREIGN KEY (${AppDatabase.columnMovieId})
          REFERENCES ${AppDatabase.moviesTable} (${AppDatabase.columnId})
          ON DELETE CASCADE
      )
    ''');
  },
);

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('movies_db_test');
    dbPath = p.join(tempDir.path, 'movies.db');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('upgrading from v1 keeps previously cached searches reachable', () async {
    final v1 = await _openV1(dbPath);
    await v1.insert(AppDatabase.moviesTable, tBlackAdamModel.toDb());
    await v1.insert(AppDatabase.searchResultsTable, {
      AppDatabase.columnQuery: 'black adam',
      AppDatabase.columnMovieId: tBlackAdamModel.id,
      AppDatabase.columnPosition: 0,
    });
    await v1.close();

    final upgraded = await AppDatabase.open(path: dbPath);
    addTearDown(upgraded.close);
    final dataSource = MovieLocalDataSourceImpl(upgraded);

    expect(
      await dataSource.getCachedSearch('black adam'),
      [tBlackAdamModel],
      reason: 'the rows were already there; only the marker table was missing',
    );
    expect(await dataSource.getCachedSearch('never searched'), isNull);
  });
}
