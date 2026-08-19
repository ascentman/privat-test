import 'package:injectable/injectable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/movie.dart';
import '../repositories/movie_repository.dart';

/// Loads a single movie by its TMDB id.
@injectable
class GetMovieDetails extends UseCase<Movie, int> {
  const GetMovieDetails(this._repository);

  final MovieRepository _repository;

  @override
  Future<Result<Movie>> call(int params) => _repository.getMovieDetails(params);
}
