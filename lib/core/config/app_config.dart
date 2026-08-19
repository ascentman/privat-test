import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration for the TMDB backend.
///
/// The API key never lives in source control: it is read from the `.env`
/// asset (see `.env.example`) at startup.
class AppConfig {
  const AppConfig({required this.apiKey});

  /// Reads the configuration from the already-loaded `.env` asset.
  factory AppConfig.fromEnv() =>
      AppConfig(apiKey: dotenv.env[apiKeyEnvName] ?? '');

  static const String apiKeyEnvName = 'TMDB_API_KEY';

  /// Asset holding the key. Git-ignored, and loaded optionally: when it is
  /// absent the app reports the missing key rather than failing to start.
  static const String envAssetPath = 'assets/env/app.env';

  static const String baseUrl = 'https://api.themoviedb.org/3';

  /// `w500` is the width TMDB recommends for list/detail posters.
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  final String apiKey;

  bool get hasApiKey => apiKey.isNotEmpty;

  /// Builds a full poster URL from the relative `poster_path` returned by the
  /// API, or `null` when the movie has no poster.
  static String? posterUrl(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) {
      return null;
    }
    return '$imageBaseUrl$posterPath';
  }
}
