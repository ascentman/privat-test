import '../../../../core/utils/result.dart';
import '../entities/movie_details_result.dart';
import '../entities/movie_search_result.dart';

/// The domain's view of movie storage. Implemented in the data layer by
/// `MovieRepositoryImpl`, which decides between network and sqflite cache.
abstract class MovieRepository {
  /// Searches TMDB one page at a time.
  ///
  /// The first page falls back to previously cached results when the network
  /// is unavailable; later pages do not, because the cache answers with
  /// everything it holds for the query and appending that to what is already
  /// on screen would duplicate it.
  Future<Result<MovieSearchResult>> searchMovies(String query, {int page = 1});

  /// Loads a single movie, falling back to the cached copy when offline —
  /// which the result says out loud.
  Future<Result<MovieDetailsResult>> getMovieDetails(int id);
}
