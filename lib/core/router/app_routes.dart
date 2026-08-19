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
}
