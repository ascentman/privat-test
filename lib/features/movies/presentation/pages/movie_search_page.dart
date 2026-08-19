import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/entities/movie.dart';
import '../../domain/usecases/search_movies.dart';
import '../bloc/movie_search/movie_search_bloc.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              key: MovieSearchPage.searchFieldKey,
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search movies',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
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
            ),
          ),
          Expanded(
            child: BlocBuilder<MovieSearchBloc, MovieSearchState>(
              builder: (context, state) => switch (state) {
                SearchInitial() => const MessageView(
                  icon: Icons.search,
                  message:
                      'Type at least ${SearchMovies.minQueryLength} '
                      'characters to search for a movie.',
                ),
                SearchLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                SearchEmpty(:final query, :final fromCache) => _WithCacheBanner(
                  fromCache: fromCache,
                  child: MessageView(
                    icon: Icons.sentiment_dissatisfied_outlined,
                    message: 'Nothing found for "$query".',
                  ),
                ),
                SearchFailure(:final failure) => MessageView(
                  icon: Icons.cloud_off,
                  message: failure.userMessage,
                  onRetry: () => context.read<MovieSearchBloc>().add(
                    const MovieSearchEvent.retried(),
                  ),
                ),
                SearchLoaded(
                  :final movies,
                  :final fromCache,
                  :final totalResults,
                ) =>
                  _ResultList(
                    movies: movies,
                    fromCache: fromCache,
                    totalResults: totalResults,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.movies,
    required this.fromCache,
    required this.totalResults,
  });

  final List<Movie> movies;
  final bool fromCache;
  final int totalResults;

  /// True when the source has more matches than this one page carries.
  bool get _isTruncated => totalResults > movies.length;

  @override
  Widget build(BuildContext context) {
    return _WithCacheBanner(
      fromCache: fromCache,
      child: ListView.separated(
        // One extra row for the truncation notice, so a partial list never
        // passes itself off as everything TMDB knows.
        itemCount: movies.length + (_isTruncated ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == movies.length) {
            return _TruncationNotice(shown: movies.length, total: totalResults);
          }
          final movie = movies[index];
          return MovieListTile(
            movie: movie,
            // `extra` renders instantly; the details bloc still reloads by
            // id so the screen is identical when opened via a deep link.
            onTap: () => context.push(AppRoutes.movie(movie.id), extra: movie),
          );
        },
      ),
    );
  }
}

/// Puts the offline banner above [child] whenever what it shows came from the
/// cache — results and "nothing found" alike.
class _WithCacheBanner extends StatelessWidget {
  const _WithCacheBanner({required this.fromCache, required this.child});

  final bool fromCache;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!fromCache) {
      return child;
    }
    return Column(
      children: [
        const _OfflineBanner(),
        Expanded(child: child),
      ],
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
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

/// Tells the user the list is only the first page of what TMDB matched.
class _TruncationNotice extends StatelessWidget {
  const _TruncationNotice({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        'Showing the first $shown of $total matches.',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
