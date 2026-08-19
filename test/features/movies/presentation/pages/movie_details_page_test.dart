import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:privat_test/core/error/failure.dart';
import 'package:privat_test/features/movies/domain/entities/movie.dart';
import 'package:privat_test/features/movies/presentation/bloc/movie_details/movie_details_bloc.dart';
import 'package:privat_test/features/movies/presentation/pages/movie_details_page.dart';
import 'package:privat_test/features/movies/presentation/widgets/message_view.dart';

import '../../../../helpers/test_data.dart';

class _MockDetailsBloc extends MockBloc<MovieDetailsEvent, MovieDetailsState>
    implements MovieDetailsBloc {}

void main() {
  late _MockDetailsBloc bloc;

  setUpAll(() {
    registerFallbackValue(const MovieDetailsEvent.requested(1));
  });

  setUp(() {
    bloc = _MockDetailsBloc();
  });

  Future<void> pumpPage(WidgetTester tester, {Movie? initialMovie}) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<MovieDetailsBloc>.value(
          value: bloc,
          child: MovieDetailsPage(
            movieId: tBlackAdam.id,
            initialMovie: initialMovie,
          ),
        ),
      ),
    );
  }

  void stub(MovieDetailsState state) => whenListen(
    bloc,
    const Stream<MovieDetailsState>.empty(),
    initialState: state,
  );

  testWidgets('requests the movie by id on open', (tester) async {
    stub(MovieDetailsState.loaded(tBlackAdam));

    await pumpPage(tester);

    verify(
      () => bloc.add(MovieDetailsEvent.requested(tBlackAdam.id)),
    ).called(1);
  });

  testWidgets('renders the movie with its rating', (tester) async {
    stub(MovieDetailsState.loaded(tBlackAdam));

    await pumpPage(tester);

    expect(find.text(tBlackAdam.title), findsWidgets);
    expect(find.text(tBlackAdam.voteAverage.toStringAsFixed(1)), findsOneWidget);
  });

  testWidgets('shows the error view when the load failed with nothing to show', (
    tester,
  ) async {
    stub(const MovieDetailsState.failure(Failure.network()));

    await pumpPage(tester);

    expect(find.byType(MessageView), findsOneWidget);
  });

  testWidgets('warns that data is stale when a refresh fails after the list '
      'already supplied a movie', (tester) async {
    stub(const MovieDetailsState.failure(Failure.network()));

    await pumpPage(tester, initialMovie: tBlackAdam);

    // The movie stays on screen, but not silently.
    expect(find.text(tBlackAdam.overview), findsOneWidget);
    expect(find.textContaining("Couldn't refresh"), findsOneWidget);
  });

  testWidgets('the stale banner can retry', (tester) async {
    stub(const MovieDetailsState.failure(Failure.network()));

    await pumpPage(tester, initialMovie: tBlackAdam);
    await tester.tap(find.text('Retry'));

    verify(
      () => bloc.add(MovieDetailsEvent.requested(tBlackAdam.id)),
    ).called(2); // once on open, once on retry
  });

  testWidgets('says when the movie was served from the device cache', (
    tester,
  ) async {
    stub(MovieDetailsState.loaded(tBlackAdam, fromCache: true));

    // No initialMovie: this is the cold-start deep link case.
    await pumpPage(tester);

    expect(find.text(tBlackAdam.overview), findsOneWidget);
    expect(find.textContaining('saved on this device'), findsOneWidget);
  });

  testWidgets('no notice when the movie came from the network', (tester) async {
    stub(MovieDetailsState.loaded(tBlackAdam));

    await pumpPage(tester);

    expect(find.byKey(const Key('movie-details-stale-banner')), findsNothing);
  });

  testWidgets('shows the optimistic movie while loading', (tester) async {
    stub(const MovieDetailsState.loading());

    await pumpPage(tester, initialMovie: tBlackAdam);

    expect(find.text(tBlackAdam.overview), findsOneWidget);
    expect(find.textContaining("Couldn't refresh"), findsNothing);
  });
}
