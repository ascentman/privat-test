import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/entities/movie.dart';
import '../../domain/usecases/search_movies.dart';
import '../bloc/movie_search/movie_search_bloc.dart';
import '../widgets/glass_header.dart';
import '../widgets/message_view.dart';
import '../widgets/movie_list_tile.dart';

/// Search screen: a query field over a table of results.
class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({super.key});

  static const Key searchFieldKey = Key('movie-search-field');

  @override
  State<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    context.read<MovieSearchBloc>().add(MovieSearchEvent.queryChanged(query));
  }

  @override
  Widget build(BuildContext context) {
    final topInset = GlassHeader.insetOf(context);

    final field = TextField(
      key: MovieSearchPage.searchFieldKey,
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _onQueryChanged,
      decoration: InputDecoration(
        hintText: 'Search movies',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    context.read<MovieSearchBloc>().add(
                      const MovieSearchEvent.cleared(),
                    );
                  },
                ),
        ),
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: BlocBuilder<MovieSearchBloc, MovieSearchState>(
              builder: (context, state) => switch (state) {
                SearchInitial() => _Centred(
                  topInset: topInset,
                  child: MessageView(
                    icon: Icons.search,
                    message:
                        'Type at least ${SearchMovies.minQueryLength} '
                        'characters to search for a movie.',
                  ),
                ),
                SearchLoading() => _Centred(
                  topInset: topInset,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                SearchEmpty(:final query, :final fromCache) => _Centred(
                  topInset: topInset,
                  child: Column(
                    children: [
                      if (fromCache) const _OfflineBanner(),
                      Expanded(
                        child: MessageView(
                          icon: Icons.sentiment_dissatisfied_outlined,
                          message: 'Nothing found for "$query".',
                        ),
                      ),
                    ],
                  ),
                ),
                SearchFailure(:final failure) => _Centred(
                  topInset: topInset,
                  child: MessageView(
                    icon: Icons.cloud_off,
                    message: failure.userMessage,
                    onRetry: () => context.read<MovieSearchBloc>().add(
                      const MovieSearchEvent.retried(),
                    ),
                  ),
                ),
                SearchLoaded(
                  :final movies,
                  :final fromCache,
                  :final totalResults,
                  :final hasMore,
                  :final isLoadingMore,
                ) =>
                  _ResultList(
                    movies: movies,
                    fromCache: fromCache,
                    totalResults: totalResults,
                    hasMore: hasMore,
                    isLoadingMore: isLoadingMore,
                    topInset: topInset,
                  ),
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GlassHeader(title: const Text('Movies'), field: field),
          ),
        ],
      ),
    );
  }
}

/// Keeps a non-scrolling state clear of the header.
class _Centred extends StatelessWidget {
  const _Centred({required this.topInset, required this.child});

  final double topInset;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topInset),
    child: child,
  );
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.movies,
    required this.fromCache,
    required this.totalResults,
    required this.hasMore,
    required this.isLoadingMore,
    required this.topInset,
  });

  final List<Movie> movies;
  final bool fromCache;
  final int totalResults;
  final bool hasMore;
  final bool isLoadingMore;
  final double topInset;

  /// Cached answers cannot grow, so a short one says how much is missing
  /// rather than pretending more is on the way.
  bool get _isTruncatedCache => fromCache && totalResults > movies.length;

  bool get _hasFooter => hasMore || isLoadingMore || _isTruncatedCache;

  @override
  Widget build(BuildContext context) {
    // The banner rides in the list rather than above it, so the rows keep
    // passing under the glass header instead of starting below a fixed one.
    final leading = fromCache ? 1 : 0;
    final trailing = _hasFooter ? 1 : 0;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Ask early enough that the next page usually lands before the user
        // reaches the end. The bloc drops the repeats this fires.
        if (hasMore &&
            !isLoadingMore &&
            notification.metrics.extentAfter < 800) {
          context.read<MovieSearchBloc>().add(
            const MovieSearchEvent.loadMoreRequested(),
          );
        }
        return false;
      },
      child: ListView.separated(
        padding: EdgeInsets.only(top: topInset, bottom: 24),
        itemCount: leading + movies.length + trailing,
        separatorBuilder: (context, index) => index < leading
            ? const SizedBox.shrink()
            : const Divider(height: 1),
        itemBuilder: (context, index) {
          if (fromCache && index == 0) {
            return const _OfflineBanner();
          }
          final movieIndex = index - leading;
          if (movieIndex == movies.length) {
            return _ListFooter(
              shown: movies.length,
              total: totalResults,
              isLoadingMore: isLoadingMore,
              cachedAndTruncated: _isTruncatedCache,
            );
          }
          final movie = movies[movieIndex];
          return MovieListTile(
            movie: movie,
            // `extra` renders instantly; the details bloc still reloads by id
            // so the screen is identical when opened via a deep link.
            onTap: () => context.push(AppRoutes.movie(movie.id), extra: movie),
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.offline_bolt_outlined,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — showing cached results',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The row after the last result: a spinner while the next page loads, or —
/// offline, where no next page is coming — how much of the answer is missing.
class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.shown,
    required this.total,
    required this.isLoadingMore,
    required this.cachedAndTruncated,
  });

  final int shown;
  final int total;
  final bool isLoadingMore;
  final bool cachedAndTruncated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cachedAndTruncated) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Text(
          'Offline — showing $shown of $total matches.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
