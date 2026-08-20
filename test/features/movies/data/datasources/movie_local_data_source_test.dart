import 'package:flutter_test/flutter_test.dart';
import 'package:privat_test/core/database/app_database.dart';
import 'package:privat_test/core/error/exceptions.dart';
import 'package:privat_test/features/movies/data/datasources/movie_local_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../helpers/test_data.dart';

/// Runs against a real in-memory sqlite database, so the schema, the
/// transaction and the ordering join are all exercised for real.
void main() {
  late Database db;
  late MovieLocalDataSourceImpl dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    dataSource = MovieLocalDataSourceImpl(db);
  });

  tearDown(() => db.close());

  test('returns cached results in the order they were stored', () async {
    await dataSource.cacheSearchResults('black adam', [
      tShazamModel,
      tBlackAdamModel,
    ]);

    final cached = await dataSource.getCachedSearch('black adam');

    expect(cached?.movies, [tShazamModel, tBlackAdamModel]);
  });

  test('replaces the previous result set for the same query', () async {
    await dataSource.cacheSearchResults('black adam', [
      tShazamModel,
      tBlackAdamModel,
    ]);
    await dataSource.cacheSearchResults('black adam', [tBlackAdamModel]);

    final cached = await dataSource.getCachedSearch('black adam');

    expect(cached?.movies, [tBlackAdamModel]);
  });

  test('keeps result sets of different queries apart', () async {
    await dataSource.cacheSearchResults('black adam', [tBlackAdamModel]);
    await dataSource.cacheSearchResults('shazam', [tShazamModel]);

    expect((await dataSource.getCachedSearch('black adam'))?.movies, [
      tBlackAdamModel,
    ]);
    expect((await dataSource.getCachedSearch('shazam'))?.movies, [
      tShazamModel,
    ]);
  });

  test('remembers how many matches the source reported', () async {
    await dataSource.cacheSearchResults('batman', [
      tBlackAdamModel,
    ], totalResults: 340);

    final cached = await dataSource.getCachedSearch('batman');

    expect(cached?.movies, [tBlackAdamModel]);
    expect(
      cached?.totalResults,
      340,
      reason: 'offline, the list must still admit it is one page of many',
    );
  });

  test('appends a later page after the stored ones', () async {
    await dataSource.cacheSearchResults('batman', [
      tBlackAdamModel,
    ], totalResults: 173);

    await dataSource.cacheSearchResults(
      'batman',
      [tShazamModel],
      page: 2,
      totalResults: 173,
    );

    final cached = await dataSource.getCachedSearch('batman');

    expect(cached?.movies, [
      tBlackAdamModel,
      tShazamModel,
    ], reason: 'page 2 continues the list rather than replacing it');
  });

  test('a fresh first page still replaces everything stored', () async {
    await dataSource.cacheSearchResults('batman', [tBlackAdamModel]);
    await dataSource.cacheSearchResults('batman', [tShazamModel], page: 2);

    await dataSource.cacheSearchResults('batman', [tShazamModel]);

    expect((await dataSource.getCachedSearch('batman'))?.movies, [
      tShazamModel,
    ]);
  });

  test('returns null for a query that was never searched', () async {
    expect(await dataSource.getCachedSearch('unseen'), isNull);
  });

  test('remembers a search that legitimately matched nothing', () async {
    // Offline, this has to stay distinguishable from "never searched":
    // one means "no such film", the other means "no idea".
    await dataSource.cacheSearchResults('zzzqqq', const []);

    expect((await dataSource.getCachedSearch('zzzqqq'))?.movies, isEmpty);
  });

  test('re-caching a movie keeps it in the results of earlier queries', () async {
    // Regression: writing a movie with ConflictAlgorithm.replace deletes and
    // re-inserts the row, and that delete fires ON DELETE CASCADE — so opening
    // a film's details used to evict it from every cached search result.
    await dataSource.cacheSearchResults('batman', [tBlackAdamModel]);

    await dataSource.cacheMovie(tBlackAdamModel);

    expect((await dataSource.getCachedSearch('batman'))?.movies, [
      tBlackAdamModel,
    ]);
  });

  test(
    'caching one query does not disturb another that shares a movie',
    () async {
      await dataSource.cacheSearchResults('black', [tBlackAdamModel]);
      await dataSource.cacheSearchResults('adam', [tBlackAdamModel]);

      expect((await dataSource.getCachedSearch('black'))?.movies, [
        tBlackAdamModel,
      ]);
      expect((await dataSource.getCachedSearch('adam'))?.movies, [
        tBlackAdamModel,
      ]);
    },
  );

  test('re-caching a movie updates its stored fields', () async {
    await dataSource.cacheMovie(tBlackAdamModel);
    await dataSource.cacheMovie(
      tBlackAdamModel.copyWith(title: 'Black Adam (2022)', voteAverage: 8.1),
    );

    final cached = await dataSource.getCachedMovie(tBlackAdamModel.id);

    expect(cached.title, 'Black Adam (2022)');
    expect(cached.voteAverage, 8.1);
  });

  test('round-trips a single movie', () async {
    await dataSource.cacheMovie(tBlackAdamModel);

    expect(
      await dataSource.getCachedMovie(tBlackAdamModel.id),
      tBlackAdamModel,
    );
  });

  test('throws CacheMissException for an unknown movie', () async {
    expect(
      () => dataSource.getCachedMovie(1),
      throwsA(isA<CacheMissException>()),
    );
  });
}
