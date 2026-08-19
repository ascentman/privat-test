import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/movie.dart';

part 'movie_model.freezed.dart';
part 'movie_model.g.dart';

/// Transport/storage representation of a movie.
///
/// JSON keys follow TMDB's snake_case, which `build.yaml` maps automatically
/// (`posterPath` <-> `poster_path`). The same class also converts to and from
/// sqflite rows, so the cache and the API share one shape.
@freezed
abstract class MovieModel with _$MovieModel {
  const MovieModel._();

  const factory MovieModel({
    required int id,
    @Default('') String title,
    @Default('') String overview,
    String? posterPath,
    @Default(0.0) double voteAverage,
    String? releaseDate,
  }) = _MovieModel;

  factory MovieModel.fromJson(Map<String, dynamic> json) =>
      _$MovieModelFromJson(json);

  factory MovieModel.fromEntity(Movie movie) => MovieModel(
    id: movie.id,
    title: movie.title,
    overview: movie.overview,
    posterPath: movie.posterPath,
    voteAverage: movie.voteAverage,
    releaseDate: movie.releaseDate,
  );

  /// Builds a model from a `movies` table row.
  factory MovieModel.fromDb(Map<String, Object?> row) => MovieModel(
    id: row[AppDatabase.columnId]! as int,
    title: row[AppDatabase.columnTitle] as String? ?? '',
    overview: row[AppDatabase.columnOverview] as String? ?? '',
    posterPath: row[AppDatabase.columnPosterPath] as String?,
    voteAverage: (row[AppDatabase.columnVoteAverage] as num? ?? 0).toDouble(),
    releaseDate: row[AppDatabase.columnReleaseDate] as String?,
  );

  Movie toEntity() => Movie(
    id: id,
    title: title,
    overview: overview,
    voteAverage: voteAverage,
    posterPath: posterPath,
    releaseDate: releaseDate,
  );

  /// Serialises into a `movies` table row.
  Map<String, Object?> toDb({DateTime? cachedAt}) => {
    AppDatabase.columnId: id,
    AppDatabase.columnTitle: title,
    AppDatabase.columnOverview: overview,
    AppDatabase.columnPosterPath: posterPath,
    AppDatabase.columnVoteAverage: voteAverage,
    AppDatabase.columnReleaseDate: releaseDate,
    AppDatabase.columnCachedAt:
        (cachedAt ?? DateTime.now()).millisecondsSinceEpoch,
  };
}
