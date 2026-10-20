import 'package:http/http.dart' as http;

/// Creates configured HTTP clients for pub.dev access.
class HttpClientFactory {
  /// Creates an [http.Client] with no special transport wrapping.
  ///
  /// Timeouts are applied per-request by [PubDevClient].
  static http.Client create({Duration? timeout}) {
    return http.Client();
  }
}
