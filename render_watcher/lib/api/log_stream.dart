import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../data/models.dart';
import 'api_client.dart';

enum LogStreamStatus {
  /// Not started, or deliberately stopped.
  idle,
  connecting,
  live,

  /// Dropped; a reconnect is already scheduled.
  retrying,

  /// 4409: Render isn't connected or nothing is watched. Retrying won't help.
  needsSetup,

  /// 4401: the token was rejected. The caller should re-authenticate.
  unauthorized,
}

/// Wraps `/logs/stream` on the backend, which proxies Render's log socket so
/// the app never holds a Render key. Reconnects with backoff; the backend
/// sends a short backfill on every connect, so a drop is cheap.
class LogStream {
  LogStream(this._client);

  final ApiClient _client;

  final _lines = StreamController<LogEntry>.broadcast();
  final _status = StreamController<LogStreamStatus>.broadcast();

  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _ping;
  int _attempt = 0;
  bool _stopped = true;
  LogStreamStatus _current = LogStreamStatus.idle;

  Stream<LogEntry> get lines => _lines.stream;
  Stream<LogStreamStatus> get status => _status.stream;
  LogStreamStatus get currentStatus => _current;

  void start() {
    if (!_stopped) return;
    _stopped = false;
    _attempt = 0;
    _connect();
  }

  void stop() {
    _stopped = true;
    _retry?.cancel();
    _ping?.cancel();
    _sub?.cancel();
    _ws?.sink.close();
    _ws = null;
    _sub = null;
    _emit(LogStreamStatus.idle);
  }

  /// After the user changes watched services the backend must re-subscribe.
  void restart() {
    if (_stopped) return start();
    _teardownSocket();
    _attempt = 0;
    _connect();
  }

  Future<void> _connect() async {
    if (_stopped) return;
    _emit(_attempt == 0 ? LogStreamStatus.connecting : LogStreamStatus.retrying);

    final token = await _client.idToken(forceRefresh: _attempt > 0);
    if (_stopped) return;
    if (token == null) {
      _emit(LogStreamStatus.unauthorized);
      return;
    }

    try {
      final ws = WebSocketChannel.connect(AppConfig.ws('/logs/stream', {'token': token}));
      await ws.ready;
      if (_stopped) {
        ws.sink.close();
        return;
      }
      _ws = ws;
      _attempt = 0;
      _emit(LogStreamStatus.live);
      // The backend's client_watch() task reads text frames; without traffic
      // some proxies drop an idle socket.
      _ping = Timer.periodic(const Duration(seconds: 25), (_) => _ws?.sink.add('ping'));
      _sub = ws.stream.listen(
        _onFrame,
        onError: (_) => _onClosed(ws),
        onDone: () => _onClosed(ws),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onFrame(dynamic frame) {
    if (frame is! String) return;
    try {
      final json = jsonDecode(frame);
      if (json is Map<String, dynamic>) _lines.add(LogEntry.fromJson(json));
    } catch (_) {
      // A malformed frame is not worth tearing the stream down for.
    }
  }

  void _onClosed(WebSocketChannel ws) {
    final code = ws.closeCode;
    _teardownSocket();
    if (_stopped) return;
    // 4401 / 4409 are set by backend/app/routers/logs.py and are terminal.
    if (code == 4401) return _emit(LogStreamStatus.unauthorized);
    if (code == 4409) return _emit(LogStreamStatus.needsSetup);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_stopped) return;
    _emit(LogStreamStatus.retrying);
    final delay = Duration(seconds: [1, 2, 4, 8, 15, 30][_attempt.clamp(0, 5)]);
    _attempt++;
    _retry?.cancel();
    _retry = Timer(delay, _connect);
  }

  void _teardownSocket() {
    _ping?.cancel();
    _ping = null;
    _sub?.cancel();
    _sub = null;
    _ws?.sink.close();
    _ws = null;
  }

  void _emit(LogStreamStatus s) {
    if (_current == s) return;
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  void dispose() {
    stop();
    _lines.close();
    _status.close();
  }
}
