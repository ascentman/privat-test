import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/movies/presentation/widgets/message_view.dart';
import 'di/injection.dart';
import 'router/app_router.dart';

class MoviesApp extends StatefulWidget {
  const MoviesApp({super.key});

  @override
  State<MoviesApp> createState() => _MoviesAppState();
}

class _MoviesAppState extends State<MoviesApp> {
  final GoRouter _router = createRouter();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    );

    // Fail loudly instead of letting every request come back as a 401.
    if (!getIt<AppConfig>().hasApiKey) {
      return MaterialApp(
        title: 'Movies',
        theme: theme,
        home: const Scaffold(
          body: MessageView(
            icon: Icons.key_off,
            message:
                'No TMDB API key found.\n\n'
                'Copy .env.example to .env and set '
                '${AppConfig.apiKeyEnvName}, then restart the app.',
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Movies',
      theme: theme,
      routerConfig: _router,
    );
  }
}
