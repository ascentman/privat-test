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
    context.read<MovieDetailsBloc>().add(
      MovieDetailsEvent.requested(widget.movieId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MovieDetailsBloc, MovieDetailsState>(
      builder: (context, state) {
        final movie = switch (state) {
          DetailsLoaded(:final movie) => movie,
          _ => widget.initialMovie,
        };
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
            _ => _DetailsBody(movie: movie!),
          },
        );
      },
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
