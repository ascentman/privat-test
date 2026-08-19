import '../../../../core/utils/result.dart';
import '../entities/movie.dart';
import '../entities/movie_search_result.dart';

/// The domain's view of movie storage. Implemented in the data layer by
/// `MovieRepositoryImpl`, which decides between network and sqflite cache.
abstract class MovieRepository {
  /// Searches TMDB, falling back to previously cached results for the same
  /// query when the network is unavailable.
  Future<Result<MovieSearchResult>> searchMovies(String query);

  /// Loads a single movie, falling back to the cached copy when offline.
  Future<Result<Movie>> getMovieDetails(int id);
}
