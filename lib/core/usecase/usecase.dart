import '../utils/result.dart';

/// A single piece of application behaviour, invoked as a function:
/// `await searchMovies('black adam')`.
abstract class UseCase<Out, In> {
  const UseCase();

  Future<Result<Out>> call(In params);
}

/// Placeholder for use cases that take no input.
class NoParams {
  const NoParams();
}
