import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../features/movies/domain/entities/movie.dart';
import '../../features/movies/presentation/bloc/movie_details/movie_details_bloc.dart';
import '../../features/movies/presentation/bloc/movie_search/movie_search_bloc.dart';
import '../../features/movies/presentation/pages/movie_details_page.dart';
import '../../features/movies/presentation/pages/movie_search_page.dart';
import '../di/injection.dart';

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
  if (match == null) {
    return null;
  }
  // tryParse, not parse: the pattern accepts any number of digits, so a
  // garbled link like `privattest://99999999999999999999` overflows a 64-bit
  // int and would otherwise throw out of the router's redirect.
  final id = int.tryParse(match.group(1)!);
  return id == null ? null : AppRoutes.movie(id);
}
