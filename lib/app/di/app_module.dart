import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/config/app_config.dart';
import '../../core/database/app_database.dart';
import '../../core/network/api_key_interceptor.dart';

/// Third-party objects that cannot be annotated in their own package.
@module
abstract class AppModule {
  @lazySingleton
  AppConfig get appConfig => AppConfig.fromEnv();

  @lazySingleton
  Dio dio(AppConfig config) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    dio.interceptors.add(ApiKeyInterceptor(config));
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: false));
    }
    return dio;
  }

  /// `@preResolve` makes `configureDependencies()` await the open database, so
  /// data sources can depend on a ready [Database] synchronously.
  @preResolve
  @lazySingleton
  Future<Database> get database => AppDatabase.open();
}
