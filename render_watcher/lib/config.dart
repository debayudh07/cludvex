/// Build-time configuration, passed with --dart-define.
///
///   flutter run --dart-define=API_BASE_URL=https://watcher.example.com
///   flutter run --dart-define=USE_MOCK=true     # offline demo, no Firebase
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');
  static const useMock = bool.fromEnvironment('USE_MOCK');

  static Uri api(String path, [Map<String, String>? query]) =>
      Uri.parse(apiBaseUrl).replace(path: path, queryParameters: query);

  static Uri ws(String path, Map<String, String> query) {
    final base = Uri.parse(apiBaseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: path,
      queryParameters: query,
    );
  }
}
