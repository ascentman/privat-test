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
import 'package:privat_test/features/movies/presentation/widgets/glass_circle_button.dart';
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
    verify(() => detailsBloc.add(const MovieDetailsEvent.requested(436270)))
        .called(1);
  });

  testWidgets('a bare numeric path opens the details screen', (tester) async {
    // Android builds the initial route from Uri.getPath() alone, so
    // `privattest://movie/436270` reaches the app as `/436270`.
    final router = await pumpApp(tester);

    router.go('/436270');
    await tester.pumpAndSettle();

    expect(find.byType(MovieDetailsPage), findsOneWidget);
    verify(() => detailsBloc.add(const MovieDetailsEvent.requested(436270)))
        .called(1);
  });

  testWidgets('a deep link leaves search underneath it', (tester) async {
    // The details route is nested under search precisely so go_router builds
    // both pages. As siblings the stack held one page, and back had nowhere to
    // go: the in-app button did nothing and the system gesture closed the app.
    final router = await pumpApp(tester);

    router.go('/movie/436270');
    await tester.pumpAndSettle();

    expect(find.byType(MovieDetailsPage), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'back must have somewhere to go');

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(MovieSearchPage), findsOneWidget);
  });

  testWidgets('the back button on a deep-linked film returns to search', (
    tester,
  ) async {
    // The stack being right is not the same as the button using it: this taps
    // the widget the user actually presses.
    final router = await pumpApp(tester);

    router.go('/movie/436270');
    await tester.pumpAndSettle();
    expect(find.byType(MovieDetailsPage), findsOneWidget);

    await tester.tap(find.byType(GlassCircleButton));
    await tester.pumpAndSettle();

    expect(find.byType(MovieSearchPage), findsOneWidget);
    expect(find.byType(MovieDetailsPage), findsNothing);
  });

  testWidgets('the same holds for the bare numeric Android form', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    router.go('/436270');
    await tester.pumpAndSettle();

    expect(find.byType(MovieDetailsPage), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

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

  testWidgets('an oversized id on the explicit route falls back to search', (
    tester,
  ) async {
    // The same bound has to hold here as for a rewritten bare path: on the web
    // int.tryParse would round rather than reject, and the app would look up a
    // different film.
    final router = await pumpApp(tester);

    router.go('/movie/99999999999999999999999');
    await tester.pumpAndSettle();

    expect(find.byType(MovieSearchPage), findsOneWidget);
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
