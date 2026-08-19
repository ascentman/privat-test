import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../data/datasources/movie_remote_data_source.dart';

/// The retrofit client is an abstract class with a generated factory, so it
/// has to be registered through a module rather than annotated directly.
@module
abstract class MoviesModule {
  @lazySingleton
  MovieRemoteDataSource movieRemoteDataSource(Dio dio) =>
      MovieRemoteDataSource(dio);
}
