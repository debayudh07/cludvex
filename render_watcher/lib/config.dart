/// Build-time configuration, passed with --dart-define.
///
///   # Android emulator reaching a backend on the host machine
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///   # physical device on the same LAN
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080
abstract final class AppConfig {
  static const apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');

  /// How often the foreground app refetches overview/alerts. Pushes arrive
  /// out of band; this is the floor, not the only path.
  static const pollInterval = Duration(seconds: 20);

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
