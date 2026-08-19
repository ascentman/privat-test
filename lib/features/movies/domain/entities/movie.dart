import 'package:freezed_annotation/freezed_annotation.dart';

part 'movie.freezed.dart';

/// A movie as the app talks about it.
///
/// Deliberately free of JSON/database concerns — those live on
/// `MovieModel` in the data layer, which converts to and from this entity.
@freezed
abstract class Movie with _$Movie {
  const factory Movie({
    required int id,
    required String title,
    required String overview,
    required double voteAverage,
    String? posterPath,
    String? releaseDate,
  }) = _Movie;
}
