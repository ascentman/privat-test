import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/movie.dart';
import '../bloc/movie_details/movie_details_bloc.dart';
import '../widgets/message_view.dart';
import '../widgets/poster_image.dart';

/// Details screen: poster, title, description, rating.
///
/// [initialMovie] is only an optimistic first frame handed over by the list;
/// the bloc always reloads by [movieId], which is what a deep link provides.
class MovieDetailsPage extends StatefulWidget {
  const MovieDetailsPage({required this.movieId, this.initialMovie, super.key});

  final int movieId;
  final Movie? initialMovie;

  @override
  State<MovieDetailsPage> createState() => _MovieDetailsPageState();
}

class _MovieDetailsPageState extends State<MovieDetailsPage> {
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => context.read<MovieDetailsBloc>().add(
    MovieDetailsEvent.requested(widget.movieId),
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MovieDetailsBloc, MovieDetailsState>(
      builder: (context, state) {
        final movie =
            switch (state) {
              DetailsLoaded(:final movie) => movie,
              // A failed refresh keeps whatever was last loaded, so a retry
              // that goes wrong does not blank a screen the user was reading.
              DetailsFailure(:final movie) => movie,
              DetailsLoading() => null,
            } ??
            widget.initialMovie;
        return Scaffold(
          appBar: AppBar(title: Text(movie?.title ?? 'Movie')),
          body: switch (state) {
            DetailsFailure(:final failure) when movie == null => MessageView(
              icon: Icons.cloud_off,
              message: failure.userMessage,
              onRetry: () => context.read<MovieDetailsBloc>().add(
                MovieDetailsEvent.requested(widget.movieId),
              ),
            ),
            DetailsLoading() when movie == null => const Center(
              child: CircularProgressIndicator(),
            ),
            // Reached when the refresh failed but the list handed us something
            // to show. Say so instead of passing stale data off as current.
            DetailsFailure(:final failure) => _DetailsBody(
              movie: movie!,
              staleNotice: failure.userMessage,
              onRetry: _reload,
            ),
            // Loaded straight from sqflite because the network was unavailable
            // — a cold-start deep link offline lands here, with no optimistic
            // movie to fall back on, so this is the only thing that tells the
            // user the rating and description may be out of date.
            DetailsLoaded(fromCache: true) => _DetailsBody(
              movie: movie!,
              staleNotice: 'showing the copy saved on this device',
              onRetry: _reload,
            ),
            _ => _DetailsBody(movie: movie!),
          },
        );
      },
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.movie, this.staleNotice, this.onRetry});

  final Movie movie;

  /// Set when the movie on screen came from the list and could not be
  /// refreshed, so the user is told rather than shown stale data as current.
  final String? staleNotice;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (staleNotice != null) ...[
            _StaleBanner(message: staleNotice!, onRetry: onRetry),
            const SizedBox(height: 16),
          ],
          Center(
            child: PosterImage(
              posterPath: movie.posterPath,
              width: 220,
              height: 330,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 20),
          Text(movie.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
              const SizedBox(width: 4),
              Text(
                movie.voteAverage.toStringAsFixed(1),
                style: theme.textTheme.titleMedium,
              ),
              Text(' / 10', style: theme.textTheme.bodyMedium),
              if (movie.releaseDate != null &&
                  movie.releaseDate!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(movie.releaseDate!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text(
            movie.overview.isEmpty
                ? 'No description available.'
                : movie.overview,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.message, this.onRetry});

  static const Key bannerKey = Key('movie-details-stale-banner');

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: bannerKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync_problem,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Couldn't refresh: $message",
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
