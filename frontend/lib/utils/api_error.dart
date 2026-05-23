import 'package:dio/dio.dart';

/// Extracts a clean, user-facing error message from any exception.
/// Reads the backend's `message` field directly from DioException responses.
String extractApiError(dynamic error) {
  if (error is DioException) {
    // Backend returned a response with a message field
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }

    // Network / connectivity issues
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your internet and try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Make sure you are connected to the internet.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        break;
    }

    // HTTP status fallbacks
    final status = error.response?.statusCode;
    if (status == 400) return 'Invalid request. Please check your inputs.';
    if (status == 401) return 'Session expired. Please log in again.';
    if (status == 403) return 'You do not have permission to do that.';
    if (status == 404) return 'Not found.';
    if (status == 429) return 'Too many requests. Please slow down.';
    if (status != null && status >= 500) return 'Server error. Please try again later.';
  }

  return 'Something went wrong. Please try again.';
}
