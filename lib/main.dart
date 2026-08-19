import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'app/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The `.env` asset holds the TMDB API key; a missing file is handled by the
  // app itself with an explanatory screen rather than a crash on launch.
  await dotenv.load(fileName: '.env', isOptional: true);
  await configureDependencies();
  runApp(const MoviesApp());
}
