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
  /// The length bound is the guard that matters, and it has to apply to every
  /// path that carries an id — the explicit `/movie/:id` route as much as a
  /// rewritten bare one. On the web `int` is a JS double, so `int.tryParse`
  /// does not reject an overlong digit string the way it does on the VM: it
  /// rounds, and the app would then look up a different, possibly real, film.
  static int? parseMovieId(String? raw) {
    if (raw == null || !_movieId.hasMatch(raw)) {
      return null;
    }
    return int.tryParse(raw);
  }
}
