import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/movies/domain/entities/movie.dart';
import '../../features/movies/presentation/bloc/movie_details/movie_details_bloc.dart';
import '../../features/movies/presentation/bloc/movie_search/movie_search_bloc.dart';
import '../../features/movies/presentation/pages/movie_details_page.dart';
import '../../features/movies/presentation/pages/movie_search_page.dart';
import '../di/injection.dart';

/// Route locations, kept in one place so deep links and in-app navigation
/// cannot drift apart.
abstract final class AppRoutes {
  static const String search = '/';
  static const String movieDetails = '/movie/:id';

  static String movie(int id) => '/movie/$id';
}

/// Matches a bare numeric location such as `/436270`.
final RegExp _bareMovieId = RegExp(r'^/(\d+)/?$');

GoRouter createRouter() => GoRouter(
  initialLocation: AppRoutes.search,
  redirect: _normalizeDeepLink,
  routes: [
    GoRoute(
      path: AppRoutes.search,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<MovieSearchBloc>(),
        child: const MovieSearchPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.movieDetails,
      redirect: (context, state) =>
          int.tryParse(state.pathParameters['id'] ?? '') == null
          ? AppRoutes.search
          : null,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return BlocProvider(
          create: (_) => getIt<MovieDetailsBloc>(),
          child: MovieDetailsPage(
            movieId: id,
            initialMovie: state.extra is Movie ? state.extra! as Movie : null,
          ),
        );
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Not found')),
    body: Center(child: Text('No route for ${state.uri}')),
  ),
);

/// Repairs deep links whose authority was stripped by the platform.
///
/// Android builds the initial route from `Uri.getPath()` only, so
/// `privattest://movie/436270` arrives as `/436270` — the `movie` host is
/// dropped. Rewriting a bare numeric path back to `/movie/<id>` makes both
/// that form and the explicit `privattest:///movie/436270` land on the same
/// screen, on every platform.
String? _normalizeDeepLink(BuildContext context, GoRouterState state) {
  final match = _bareMovieId.firstMatch(state.uri.path);
  return match == null ? null : AppRoutes.movie(int.parse(match.group(1)!));
}
