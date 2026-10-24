import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  bool get unauthorized => status == 401;
  bool get notConnected => status == 409;

  @override
  String toString() => message;
}

/// HTTP wrapper: attaches the Firebase ID token and decodes JSON.
class ApiClient {
  ApiClient({http.Client? http, Future<String?> Function()? token})
      : _http = http ?? _defaultClient(),
        _token = token ?? _firebaseToken;

  final http.Client _http;
  final Future<String?> Function() _token;

  static http.Client _defaultClient() => http.Client();

  static Future<String?> _firebaseToken() async => FirebaseAuth.instance.currentUser?.getIdToken();

  Future<String?> idToken() => _token();

  Future<dynamic> get(String path, [Map<String, String>? query]) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, Object body) => _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    final token = await _token();
    final req = http.Request(method, AppConfig.api(path, query))
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } catch (_) {
      throw ApiException(0, "Can't reach the Render Watcher server");
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiException(res.statusCode, detail is String ? detail : 'Request failed (${res.statusCode})');
    }
    return decoded;
  }
}
