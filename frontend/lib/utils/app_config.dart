import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Centralised runtime configuration.
///
/// Build-time overrides (highest priority):
///   flutter build web  --dart-define=API_URL=https://api.myapp.com
///   flutter build apk  --dart-define=API_URL=https://api.myapp.com
///                      --dart-define=SOCKET_URL=https://api.myapp.com
///                      --dart-define=MEDIA_URL=https://api.myapp.com
class AppConfig {
  // Injected at build time via --dart-define; empty string when not provided.
  static const String _envApiUrl = String.fromEnvironment('API_URL');
  static const String _envSocketUrl = String.fromEnvironment('SOCKET_URL');
  static const String _envMediaUrl = String.fromEnvironment('MEDIA_URL');

  /// Base URL for REST API calls (includes /api suffix).
  static String get apiBaseUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// Base URL for Socket.io connection (no /api suffix).
  static String get socketBaseUrl {
    if (_envSocketUrl.isNotEmpty) return _envSocketUrl;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  /// Base URL for resolving relative media/image paths.
  static String get mediaBaseUrl {
    if (_envMediaUrl.isNotEmpty) return _envMediaUrl;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
