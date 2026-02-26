/// Base class for all Niskala Model Gen specific exceptions.
class NiskalaException implements Exception {
  /// Creates a [NiskalaException] instance.
  NiskalaException(this.message, [this.originalError]);

  /// A human-readable message describing the error.
  final String message;

  /// The original error object, if any, that caused this exception.
  final dynamic originalError;

  @override
  String toString() {
    if (originalError != null) {
      return '$message (Original error: $originalError)';
    }
    return message;
  }
}

/// Thrown when an authentication-related error occurs.
class AuthException extends NiskalaException {
  /// Creates an [AuthException] instance.
  AuthException(super.message, [super.originalError]);
}

/// Thrown when there is an error parsing or fetching metadata.
class MetadataException extends NiskalaException {
  /// Creates a [MetadataException] instance.
  MetadataException(super.message, [super.originalError]);
}

/// Thrown when there is an error in the YAML configuration.
class ConfigException extends NiskalaException {
  /// Creates a [ConfigException] instance.
  ConfigException(super.message, [super.originalError]);
}
