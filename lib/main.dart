import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'app/di/injection.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Holds the TMDB API key and is git-ignored, so it may legitimately be
  // absent: the app then says so on screen instead of crashing on launch.
  await dotenv.load(fileName: AppConfig.envAssetPath, isOptional: true);
  await configureDependencies();
  runApp(const MoviesApp());
}
