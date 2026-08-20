/// Route locations, kept in one place so deep links and in-app navigation
/// cannot drift apart.
///
/// Lives in `core` rather than beside the router: the router imports the
/// feature pages, so a page reaching back into `app/router` for these would
/// close an import cycle.
abstract final class AppRoutes {
  static const String search = '/';
  static const String movieDetails = '/movie/:id';

  static String movie(int id) => '/movie/$id';

  /// A TMDB id is at most ten digits; anything longer is not an id we could
  /// have produced.
  static final RegExp _movieId = RegExp(r'^\d{1,10}$');

  /// Parses a movie id from a route, or `null` when it is not one.
  ///
  /// The length bound applies to every path carrying an id — the explicit
  /// `/movie/:id` route as much as a rewritten bare one. On the VM an overlong
  /// digit string already fails to parse, so the bound is belt and braces
  /// there; it stops mattering only as long as this stays off the web, where
  /// `int` is a JS double and such a string rounds to a different, possibly
  /// real, film instead of failing.
  static int? parseMovieId(String? raw) {
    if (raw == null || !_movieId.hasMatch(raw)) {
      return null;
    }
    return int.tryParse(raw);
  }
}
