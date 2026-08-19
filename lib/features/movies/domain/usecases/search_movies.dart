import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/movie_search_result.dart';
import '../repositories/movie_repository.dart';

/// Searches movies by title.
///
/// Enforces the spec's minimum query length here rather than in the UI, so
/// the rule holds for every caller (search screen, deep link, tests).
@injectable
class SearchMovies extends UseCase<MovieSearchResult, String> {
  const SearchMovies(this._repository);

  /// Minimum number of characters required to trigger a search.
  static const int minQueryLength = 2;

  final MovieRepository _repository;

  @override
  Future<Result<MovieSearchResult>> call(String params) {
    final query = params.trim();
    if (query.length < minQueryLength) {
      return Future.value(
        const Result.err(Failure.queryTooShort(minQueryLength)),
      );
    }
    return _repository.searchMovies(query);
  }
}
