import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';

/// TMDB poster with a graceful placeholder for movies that have none.
///
/// `cached_network_image` keeps posters on disk, so scrolling back through a
/// result list — or opening it offline — does not re-download every image.
class PosterImage extends StatelessWidget {
  const PosterImage({
    required this.posterPath,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.size = AppConfig.posterSizeList,
    super.key,
  });

  final String? posterPath;
  final double width;
  final double height;
  final double borderRadius;

  /// Which TMDB width to request; see [AppConfig.posterSizeDetail].
  final String size;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.posterUrl(posterPath, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? _placeholder(context)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (context, _) => _placeholder(context),
                errorWidget: (context, _, _) => _placeholder(context),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.movie_outlined,
      size: width / 2.5,
      color: Theme.of(context).colorScheme.outline,
    ),
  );
}
