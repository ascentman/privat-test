import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:privat_test/app/di/injection.dart';
import 'package:privat_test/app/router/app_router.dart';
import 'package:privat_test/features/movies/presentation/bloc/movie_details/movie_details_bloc.dart';
import 'package:privat_test/features/movies/presentation/bloc/movie_search/movie_search_bloc.dart';
import 'package:privat_test/features/movies/presentation/pages/movie_details_page.dart';
import 'package:privat_test/features/movies/presentation/pages/movie_search_page.dart';

import '../../helpers/test_data.dart';

class _MockSearchBloc extends MockBloc<MovieSearchEvent, MovieSearchState>
    implements MovieSearchBloc {}

class _MockDetailsBloc extends MockBloc<MovieDetailsEvent, MovieDetailsState>
    implements MovieDetailsBloc {}

void main() {
  late _MockSearchBloc searchBloc;
  late _MockDetailsBloc detailsBloc;

  setUpAll(() {
    registerFallbackValue(const MovieDetailsEvent.requested(1));
  });

  setUp(() {
    searchBloc = _MockSearchBloc();
    detailsBloc = _MockDetailsBloc();
    whenListen(
      searchBloc,
      const Stream<MovieSearchState>.empty(),
      initialState: const MovieSearchState.initial(),
    );
    whenListen(
      detailsBloc,
      const Stream<MovieDetailsState>.empty(),
      initialState: MovieDetailsState.loaded(tBlackAdam),
    );
    getIt
      ..registerFactory<MovieSearchBloc>(() => searchBloc)
      ..registerFactory<MovieDetailsBloc>(() => detailsBloc);
  });

  tearDown(() => getIt.reset());

  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final router = createRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('starts on the search screen', (tester) async {
    await pumpApp(tester);

    expect(find.byType(MovieSearchPage), findsOneWidget);
  });

  testWidgets('/movie/<id> opens the details screen', (tester) async {
    final router = await pumpApp(tester);

    router.go('/movie/436270');
    await tester.pumpAndSettle();

    expect(find.byType(MovieDetailsPage), findsOneWidget);
    verify(
      () => detailsBloc.add(const MovieDetailsEvent.requested(436270)),
    ).called(1);
  });

  testWidgets(
    'a bare numeric path opens the details screen',
    (tester) async {
      // Android builds the initial route from Uri.getPath() alone, so
      // `privattest://movie/436270` reaches the app as `/436270`.
      final router = await pumpApp(tester);

      router.go('/436270');
      await tester.pumpAndSettle();

      expect(find.byType(MovieDetailsPage), findsOneWidget);
      verify(
        () => detailsBloc.add(const MovieDetailsEvent.requested(436270)),
      ).called(1);
    },
  );

  testWidgets('an implausibly long numeric path is not treated as an id', (
    tester,
  ) async {
    // Too long to be a TMDB id, and on the web too long to survive int
    // parsing intact. It must not reach the details screen, and must not
    // throw out of the redirect on the way.
    final router = await pumpApp(tester);

    router.go('/99999999999999999999');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MovieDetailsPage), findsNothing);
    verifyNever(() => detailsBloc.add(any()));
  });

  testWidgets('a ten-digit path is still accepted as an id', (tester) async {
    final router = await pumpApp(tester);

    router.go('/1234567890');
    await tester.pumpAndSettle();

    expect(find.byType(MovieDetailsPage), findsOneWidget);
  });

  testWidgets('a non-numeric movie id falls back to search', (tester) async {
    final router = await pumpApp(tester);

    router.go('/movie/not-an-id');
    await tester.pumpAndSettle();

    expect(find.byType(MovieSearchPage), findsOneWidget);
    expect(find.byType(MovieDetailsPage), findsNothing);
  });
}
