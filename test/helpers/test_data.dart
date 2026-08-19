import 'package:privat_test/features/movies/data/models/movie_model.dart';
import 'package:privat_test/features/movies/domain/entities/movie.dart';

const MovieModel tBlackAdamModel = MovieModel(
  id: 436270,
  title: 'Black Adam',
  overview: 'Nearly 5,000 years after he was bestowed with powers...',
  posterPath: '/3zXceNTtyj5FLjwQXuPvLYK5YYL.jpg',
  voteAverage: 7.2,
  releaseDate: '2022-10-19',
);

const MovieModel tShazamModel = MovieModel(
  id: 287947,
  title: 'Shazam!',
  overview: 'A boy is given the ability to become an adult superhero...',
  posterPath: '/xnopI5Xtky18MPhK40nZsxdrqe7.jpg',
  voteAverage: 6.9,
  releaseDate: '2019-03-29',
);

final Movie tBlackAdam = tBlackAdamModel.toEntity();
final Movie tShazam = tShazamModel.toEntity();
