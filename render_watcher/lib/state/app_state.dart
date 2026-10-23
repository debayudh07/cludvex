import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/mock_data.dart';
import '../data/models.dart';

enum AlertFilter { all, critical, warning, yourCall, resolved }

extension AlertFilterLabel on AlertFilter {
  String get label => switch (this) {
        AlertFilter.all => 'All',
        AlertFilter.critical => 'Critical',
        AlertFilter.warning => 'Warning',
        AlertFilter.yourCall => 'Your call',
        AlertFilter.resolved => 'Resolved',
      };
}

/// `null` service filter means all services; [errorsOnly] narrows by level.
class LogFilter {
  const LogFilter({this.serviceId, this.errorsOnly = false});

  final String? serviceId;
  final bool errorsOnly;

  bool matches(LogEntry e) {
    if (serviceId != null && e.serviceId != serviceId) return false;
    if (errorsOnly && e.level != LogLevel.err && e.level != LogLevel.wrn) {
      return false;
    }
    return true;
  }
}

class ToastData {
  const ToastData(this.message, {this.onUndo, this.bottomInset = 0});

  final String message;
  final VoidCallback? onUndo;
  final double bottomInset;
}

/// App-wide state. Swap the mock sources for the FastAPI backend later.
class AppState extends ChangeNotifier {
  AppState() {
    _seedLogs();
  }

  // ---- watched services
  final Set<String> watched = {'billing', 'api', 'site'};

  List<RenderService> get watchedServices =>
      MockData.services.where((s) => watched.contains(s.id)).toList();

  void setWatched(Set<String> ids) {
    watched
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  // ---- alerts
  final Set<String> _ignored = {};
  AlertFilter filter = AlertFilter.all;

  List<Alert> get _live =>
      MockData.alerts.where((a) => !_ignored.contains(a.id)).toList();

  List<Alert> get openAlerts => _live.where((a) => a.isOpen).toList();

  List<Alert> get filteredAlerts => _live.where((a) {
        return switch (filter) {
          AlertFilter.all => true,
          AlertFilter.critical => a.severity == Severity.critical,
          AlertFilter.warning => a.severity == Severity.warning,
          AlertFilter.yourCall => a.isOpen && a.confidence * 100 < gate,
          AlertFilter.resolved => a.severity == Severity.resolved,
        };
      }).toList();

  void setFilter(AlertFilter f) {
    if (f == filter) return;
    filter = f;
    notifyListeners();
  }

  void ignore(String id) {
    _ignored.add(id);
    notifyListeners();
  }

  void unignore(String id) {
    _ignored.remove(id);
    notifyListeners();
  }

  // ---- mandate
  int gate = 75;
  bool pushAlerts = true;
  bool verifier = true;
  bool groupLines = true;
  bool autoRestart = false;

  void setGate(int v) {
    gate = v;
    notifyListeners();
  }

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  // ---- live logs
  static const _bufferSize = 400;
  final List<LogEntry> _logs = [];
  int _cursor = 0;
  bool paused = false;
  LogFilter logFilter = const LogFilter();
  Timer? _ticker;

  List<LogEntry> get logs => _logs;

  List<LogEntry> visibleLogs({int limit = 60}) {
    final out = <LogEntry>[];
    for (var i = _logs.length - 1; i >= 0 && out.length < limit; i--) {
      if (logFilter.matches(_logs[i])) out.add(_logs[i]);
    }
    return out; // newest first
  }

  LogEntry get newestLog => _logs.last;

  void startStreaming() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (paused) return;
      _append();
      notifyListeners();
    });
  }

  void setPaused(bool v) {
    paused = v;
    notifyListeners();
  }

  void setLogFilter(LogFilter f) {
    logFilter = f;
    notifyListeners();
  }

  void _seedLogs() {
    for (var i = 0; i < 40; i++) {
      _append();
    }
  }

  void _append() {
    final t = MockData.logTemplates[_cursor % MockData.logTemplates.length];
    final secs = 14 * 3600 + 5 * 60 + (_cursor * 1.3).floor();
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(secs ~/ 3600)}:${two((secs ~/ 60) % 60)}:${two(secs % 60)}';
    _logs.add(LogEntry(
      index: _cursor,
      time: time,
      level: t.$1,
      serviceId: t.$2,
      message: t.$3,
      flagged: t.$4,
    ));
    if (_logs.length > _bufferSize) _logs.removeAt(0);
    _cursor++;
  }

  // ---- toast (rendered above every route)
  final toast = ValueNotifier<ToastData?>(null);
  Timer? _toastTimer;

  void showToast(String message, {VoidCallback? onUndo, double bottomInset = 0}) {
    _toastTimer?.cancel();
    toast.value = ToastData(message, onUndo: onUndo, bottomInset: bottomInset);
    _toastTimer = Timer(const Duration(seconds: 4), () => toast.value = null);
  }

  void dismissToast() {
    _toastTimer?.cancel();
    toast.value = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _toastTimer?.cancel();
    toast.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Subscribes the caller to changes.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads without subscribing, for callbacks.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
