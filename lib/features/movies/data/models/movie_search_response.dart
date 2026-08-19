import 'package:freezed_annotation/freezed_annotation.dart';

import 'movie_model.dart';

part 'movie_search_response.freezed.dart';
part 'movie_search_response.g.dart';

/// Envelope returned by `GET /search/movie`.
@freezed
abstract class MovieSearchResponse with _$MovieSearchResponse {
  const factory MovieSearchResponse({
    @Default(1) int page,
    @Default(<MovieModel>[]) List<MovieModel> results,
    @Default(0) int totalPages,
    @Default(0) int totalResults,
  }) = _MovieSearchResponse;

  factory MovieSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$MovieSearchResponseFromJson(json);
}
