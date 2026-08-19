/// Thrown by data sources when the local sqflite cache cannot be read or
/// written. Repositories translate it into a [CacheFailure].
class CacheException implements Exception {
  const CacheException([this.message]);

  final String? message;

  @override
  String toString() => 'CacheException(${message ?? ''})';
}

/// Thrown when the cache has no entry for the requested key.
class CacheMissException extends CacheException {
  const CacheMissException([super.message]);
}
