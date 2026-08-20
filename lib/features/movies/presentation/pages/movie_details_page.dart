import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/entities/movie.dart';
import '../bloc/movie_details/movie_details_bloc.dart';
import '../widgets/glass_circle_button.dart';
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

        final body = switch (state) {
          DetailsFailure(:final failure) when movie == null => MessageView(
            icon: Icons.cloud_off,
            message: failure.userMessage,
            onRetry: _reload,
          ),
          DetailsLoading() when movie == null => const Center(
            child: CircularProgressIndicator(),
          ),
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
        };

        // No app bar: the poster reaches the top of the viewport, and the only
        // chrome is a frosted button floating over it.
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: body),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                child: GlassCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  semanticLabel: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.movie, this.staleNotice, this.onRetry});

  final Movie movie;

  /// Set when the movie on screen could not be refreshed, so the user is told
  /// rather than shown stale data as current.
  final String? staleNotice;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      // No horizontal padding here: the poster is meant to reach both edges.
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PosterHeader(movie: movie),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            // Full width so the Wrap inside can actually centre itself; the
            // column aligns children to the start and would otherwise shrink
            // it to the chips' own width.
            child: SizedBox(
              width: double.infinity,
              child: _MetaChips(movie: movie),
            ),
          ),
          if (staleNotice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _StaleBanner(message: staleNotice!, onRetry: onRetry),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              movie.overview.isEmpty
                  ? 'No description available.'
                  : movie.overview,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed poster with the page background rising into its lower half, so
/// the image ends in the scaffold colour instead of a hard horizontal edge.
class _PosterHeader extends StatelessWidget {
  const _PosterHeader({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final size = MediaQuery.sizeOf(context);
    // TMDB posters are 2:3. Capped so the title still lands above the fold on
    // a tall phone.
    final height = math.min(size.width * 1.5, size.height * 0.72);
    final year = _releaseYear(movie.releaseDate);

    return SizedBox(
      width: size.width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PosterImage(
            posterPath: movie.posterPath,
            width: size.width,
            height: height,
            borderRadius: 0,
            size: AppConfig.posterSizeDetail,
          ),
          // Darkens the top so the glass bar's back button stays legible over
          // a bright poster.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x66000000), Color(0x00000000)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  surface,
                  surface.withValues(alpha: 0.85),
                  surface.withValues(alpha: 0),
                ],
                stops: const [0, 0.18, 0.62],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  movie.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                if (year != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    year,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pill row under the poster. Only the rating for now: the year already
/// sits under the title, and genres — which the reference design shows here —
/// come from the details endpoint, which neither the model nor the cache
/// carries yet.
class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        _Chip(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_border_rounded, size: 18),
              const SizedBox(width: 6),
              Text(
                movie.voteAverage.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.labelLarge!.copyWith(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}

/// `2022-10-19` -> `2022`; null when TMDB gave no usable date.
String? _releaseYear(String? releaseDate) {
  if (releaseDate == null || releaseDate.length < 4) {
    return null;
  }
  final year = releaseDate.substring(0, 4);
  return int.tryParse(year) == null ? null : year;
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
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
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
