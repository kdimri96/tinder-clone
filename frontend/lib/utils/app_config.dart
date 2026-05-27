import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Centralised runtime configuration.
///
/// Build-time overrides (highest priority):
///   flutter build web  --dart-define=API_BASE_URL=https://api.myapp.com/api
///   flutter build apk  --dart-define=API_BASE_URL=https://api.myapp.com/api
///                      --dart-define=SOCKET_BASE_URL=https://api.myapp.com
class AppConfig {
  // Injected at build time via --dart-define; empty string when not provided.
  static const String _envApiUrl = String.fromEnvironment('API_BASE_URL');
  static const String _envSocketUrl = String.fromEnvironment('SOCKET_BASE_URL');
  static const String _envMediaUrl = String.fromEnvironment('MEDIA_BASE_URL');

  // Derive socket/media from API_BASE_URL if not explicitly set
  static String get _baseFromApi {
    if (_envApiUrl.isNotEmpty) {
      // Strip /api suffix to get the base server URL
      return _envApiUrl.endsWith('/api')
          ? _envApiUrl.substring(0, _envApiUrl.length - 4)
          : _envApiUrl;
    }
    return '';
  }

  /// Base URL for REST API calls (includes /api suffix).
  static String get apiBaseUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    if (kIsWeb) return 'http://localhost:3333/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3333/api';
    }
    return 'http://localhost:3333/api';
  }

  /// Base URL for Socket.io connection (no /api suffix).
  static String get socketBaseUrl {
    if (_envSocketUrl.isNotEmpty) return _envSocketUrl;
    if (_baseFromApi.isNotEmpty) return _baseFromApi;
    if (kIsWeb) return 'http://localhost:3333';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3333';
    }
    return 'http://localhost:3333';
  }

  /// Base URL for resolving relative media/image paths.
  static String get mediaBaseUrl {
    if (_envMediaUrl.isNotEmpty) return _envMediaUrl;
    if (_baseFromApi.isNotEmpty) return _baseFromApi;
    if (kIsWeb) return 'http://localhost:3333';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3333';
    }
    return 'http://localhost:3333';
  }
}
