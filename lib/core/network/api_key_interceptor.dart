import 'package:dio/dio.dart';

import '../config/app_config.dart';

final RegExp _apiKeyPattern = RegExp(r'api_key=[^&\s]+');

/// Replaces the API key in anything about to be logged.
String redactApiKey(String text) =>
    text.replaceAll(_apiKeyPattern, 'api_key=***');

/// Appends the TMDB `api_key` query parameter to every outgoing request so
/// individual endpoint definitions stay free of auth concerns.
class ApiKeyInterceptor extends Interceptor {
  const ApiKeyInterceptor(this._config);

  final AppConfig _config;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.queryParameters = {
      ...options.queryParameters,
      'api_key': _config.apiKey,
    };
    handler.next(options);
  }
}
