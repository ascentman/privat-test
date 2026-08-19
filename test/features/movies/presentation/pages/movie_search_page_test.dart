import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:privat_test/core/error/failure.dart';
import 'package:privat_test/features/movies/presentation/bloc/movie_search/movie_search_bloc.dart';
import 'package:privat_test/features/movies/presentation/pages/movie_search_page.dart';
import 'package:privat_test/features/movies/presentation/widgets/movie_list_tile.dart';

import '../../../../helpers/test_data.dart';

class _MockMovieSearchBloc extends MockBloc<MovieSearchEvent, MovieSearchState>
    implements MovieSearchBloc {}

void main() {
  late _MockMovieSearchBloc bloc;

  setUpAll(() {
    registerFallbackValue(const MovieSearchEvent.retried());
  });

  setUp(() {
    bloc = _MockMovieSearchBloc();
  });

  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<MovieSearchBloc>.value(
        value: bloc,
        child: const MovieSearchPage(),
      ),
    ),
  );

  testWidgets('prompts for a longer query in the initial state', (tester) async {
    whenListen(
      bloc,
      const Stream<MovieSearchState>.empty(),
      initialState: const MovieSearchState.initial(),
    );

    await pumpPage(tester);

    expect(find.textContaining('at least 2'), findsOneWidget);
  });

  testWidgets('renders one tile per result', (tester) async {
    whenListen(
      bloc,
      const Stream<MovieSearchState>.empty(),
      initialState: MovieSearchState.loaded(movies: [tBlackAdam, tShazam]),
    );

    await pumpPage(tester);

    expect(find.byType(MovieListTile), findsNWidgets(2));
    expect(find.text('Black Adam'), findsOneWidget);
    expect(find.text('Shazam!'), findsOneWidget);
  });

  testWidgets('shows the offline banner for cached results', (tester) async {
    whenListen(
      bloc,
      const Stream<MovieSearchState>.empty(),
      initialState: MovieSearchState.loaded(
        movies: [tBlackAdam],
        fromCache: true,
      ),
    );

    await pumpPage(tester);

    expect(find.textContaining('cached'), findsOneWidget);
  });

  testWidgets('shows the offline banner when even "nothing found" is cached', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<MovieSearchState>.empty(),
      initialState: const MovieSearchState.empty('zzzz', fromCache: true),
    );

    await pumpPage(tester);

    expect(find.textContaining('Nothing found'), findsOneWidget);
    expect(find.textContaining('cached'), findsOneWidget);
  });

  testWidgets('shows no banner for a fresh empty result', (tester) async {
    whenListen(
      bloc,
      const Stream<MovieSearchState>.empty(),
      initialState: const MovieSearchState.empty('zzzz'),
    );

    await pumpPage(tester);

    expect(find.textContaining('Nothing found'), findsOneWidget);
    expect(find.textContaining('cached'), findsNothing);
  });

  testWidgets('the clear button resets without waiting for the debounce', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<MovieSearchState>.empty(),
      initialState: MovieSearchState.loaded(movies: [tBlackAdam]),
    );

    await pumpPage(tester);
    await tester.enterText(find.byKey(MovieSearchPage.searchFieldKey), 'black');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.clear));

    verify(() => bloc.add(const MovieSearchEvent.cleared())).called(1);
  });

  testWidgets('typing dispatches a query event', (tester) async {
    whenListen(
      bloc,
      const Stream<MovieSearchState>.empty(),
      initialState: const MovieSearchState.initial(),
    );

    await pumpPage(tester);
    await tester.enterText(
      find.byKey(MovieSearchPage.searchFieldKey),
      'black adam',
    );

    verify(
      () => bloc.add(const MovieSearchEvent.queryChanged('black adam')),
    ).called(1);
  });

  testWidgets('retry button dispatches a retry event', (tester) async {
    whenListen(
      bloc,
      const Stream<MovieSearchState>.empty(),
      initialState: const MovieSearchState.failure(Failure.network()),
    );

    await pumpPage(tester);
    await tester.tap(find.text('Retry'));

    verify(() => bloc.add(const MovieSearchEvent.retried())).called(1);
  });
}
