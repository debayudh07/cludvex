import 'dart:async';

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../api/log_stream.dart';
import '../api/repository.dart';
import '../config.dart';
import '../data/models.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';

export '../api/repository.dart' show AlertFilter, AlertFilterWire;

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

/// Where the app should open after sign-in. Decided by GET /me so a
/// reinstall lands the user back where they left off.
enum StartPoint { signIn, connectRender, pickServices, home }

/// App-wide state over the FastAPI backend. Clients cannot read Firestore
/// (the rules deny everything), so freshness is: 20s foreground polling,
/// plus an immediate refetch whenever a push arrives, plus pull-to-refresh.
class AppState extends ChangeNotifier {
  AppState({Repository? repository, AuthService? auth, PushService? push})
      : repo = repository ?? Repository(),
        auth = auth ?? AuthService() {
    this.push = push ?? PushService(repo);
    logs = LogStream(repo.client);
  }

  final Repository repo;
  final AuthService auth;
  late final PushService push;
  late final LogStream logs;

  // ---- account -------------------------------------------------------------
  Me? me;
  bool meLoading = false;
  String? meError;

  bool get signedIn => auth.signedIn;
  bool get actionsEnabled => me?.actionsEnabled ?? false;
  int get maxWatched => me?.maxWatched ?? 3;

  StartPoint get startPoint {
    if (!signedIn) return StartPoint.signIn;
    final m = me;
    if (m == null) return StartPoint.signIn;
    if (!m.renderConnected) return StartPoint.connectRender;
    if (m.watchedCount == 0) return StartPoint.pickServices;
    return StartPoint.home;
  }

  /// Called once the user is authenticated: loads everything the shell needs
  /// and wires push. Returns where to send them.
  Future<StartPoint> bootstrap() async {
    meLoading = true;
    meError = null;
    notifyListeners();
    try {
      me = await repo.me();
      meError = null;
    } on ApiException catch (e) {
      meError = e.message;
      meLoading = false;
      notifyListeners();
      return StartPoint.signIn;
    }
    meLoading = false;
    notifyListeners();

    // Registering the device needs an authenticated backend, so it happens
    // here rather than at app start.
    unawaited(push.start());
    _wirePush();

    if (startPoint == StartPoint.home) {
      await Future.wait([refreshOverview(), refreshAlerts(), refreshMandate()]);
      startPolling();
      logs.start();
    }
    return startPoint;
  }

  bool _pushWired = false;

  void _wirePush() {
    if (_pushWired) return;
    _pushWired = true;
    push.received.listen((p) async {
      await Future.wait([refreshOverview(), refreshAlerts()]);
      final hit = _find(p.alertId);
      if (hit != null) setIncoming(hit);
    });
    push.opened.listen((p) async {
      await refreshAlerts();
      pendingOpen = p.alertId;
      notifyListeners();
    });
  }

  /// An alert id a notification tap asked us to open; the shell consumes it.
  String? pendingOpen;

  void consumePendingOpen() {
    pendingOpen = null;
  }

  Future<void> signOut() async {
    stopPolling();
    logs.stop();
    await push.unregister();
    await auth.signOut();
    me = null;
    _overview = const Overview();
    _byFilter.clear();
    _activity.clear();
    _logBuffer.clear();
    mandate = const MandateData();
    incoming = null;
    notifyListeners();
  }

  // ---- services ------------------------------------------------------------
  Overview _overview = const Overview();
  bool overviewLoading = false;
  String? overviewError;

  Overview get overview => _overview;
  List<RenderService> get watchedServices => _overview.services;
  Set<String> get watched => {for (final s in _overview.services) s.id};

  RenderService? serviceById(String id) {
    for (final s in _overview.services) {
      if (s.id == id) return s;
    }
    for (final s in allServices) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// A name for a service id even when it isn't watched any more.
  String serviceLabel(String id) => serviceById(id)?.shortName ?? id;

  Future<void> refreshOverview() async {
    overviewLoading = _overview.services.isEmpty;
    notifyListeners();
    try {
      _overview = await repo.overview();
      overviewError = null;
    } on ApiException catch (e) {
      overviewError = e.message;
    } finally {
      overviewLoading = false;
      notifyListeners();
    }
  }

  /// Every service the Render key can see, for the picker.
  List<RenderService> allServices = [];
  bool servicesLoading = false;
  String? servicesError;

  Future<void> loadAllServices() async {
    servicesLoading = true;
    servicesError = null;
    notifyListeners();
    try {
      allServices = await repo.services();
    } on ApiException catch (e) {
      servicesError = e.message;
    } finally {
      servicesLoading = false;
      notifyListeners();
    }
  }

  Future<List<RenderService>> connectRender(String apiKey) async {
    final found = await repo.connectRender(apiKey);
    allServices = found;
    me = me?.copyWith(renderConnected: true, keyLast4: apiKey.substring(apiKey.length - 4));
    notifyListeners();
    return found;
  }

  Future<void> setWatched(Set<String> ids) async {
    final updated = await repo.setWatched(ids);
    _overview = Overview(
      services: updated,
      activity: _overview.activity,
      openAlerts: _overview.openAlerts,
      critical: _overview.critical,
      warning: _overview.warning,
      yourCall: _overview.yourCall,
    );
    me = me?.copyWith(watchedCount: updated.length);
    notifyListeners();
    // The backend subscribes to Render per watched service, so the socket
    // has to be re-established to pick up the new set.
    logs.restart();
    unawaited(refreshOverview());
  }

  // ---- alerts --------------------------------------------------------------
  final Map<AlertFilter, List<Alert>> _byFilter = {};
  AlertFilter filter = AlertFilter.all;
  bool alertsLoading = false;
  String? alertsError;

  List<Alert> get filteredAlerts => _byFilter[filter] ?? const [];
  List<Alert> get allAlerts => _byFilter[AlertFilter.all] ?? const [];
  List<Alert> get openAlerts => [for (final a in allAlerts) if (a.isOpen) a];

  int get openAlertCount => _overview.openAlerts;
  int get criticalCount => _overview.critical;
  int get warningCount => _overview.warning;
  int get yourCallCount => _overview.yourCall;

  /// Evidence lines the agent has read across the open alerts — the "N lines
  /// → M alerts" line on the alerts screen.
  int get evidenceLineCount {
    var n = 0;
    for (final a in openAlerts) {
      n += a.occurrences;
    }
    return n;
  }

  void setFilter(AlertFilter f) {
    if (f == filter) return;
    filter = f;
    notifyListeners();
    if (!_byFilter.containsKey(f)) unawaited(refreshAlerts(f));
  }

  Future<void> refreshAlerts([AlertFilter? which]) async {
    final f = which ?? filter;
    alertsLoading = !_byFilter.containsKey(f);
    notifyListeners();
    try {
      _byFilter[f] = await repo.alerts(f);
      // The "all" list backs the counts and the banner, so keep it warm.
      if (f != AlertFilter.all) {
        _byFilter[AlertFilter.all] = await repo.alerts(AlertFilter.all);
      }
      alertsError = null;
    } on ApiException catch (e) {
      alertsError = e.message;
    } finally {
      alertsLoading = false;
      notifyListeners();
    }
  }

  Alert? _find(String id) {
    for (final list in _byFilter.values) {
      for (final a in list) {
        if (a.id == id) return a;
      }
    }
    return null;
  }

  /// Full detail including evidence, which GET /alerts omits.
  Future<Alert> alertDetail(String id) async {
    final full = await repo.alert(id);
    _replace(full);
    notifyListeners();
    return full;
  }

  void _replace(Alert a) {
    for (final entry in _byFilter.entries) {
      final i = entry.value.indexWhere((x) => x.id == a.id);
      if (i >= 0) entry.value[i] = a;
    }
  }

  void _removeEverywhere(String id) {
    for (final list in _byFilter.values) {
      list.removeWhere((a) => a.id == id);
    }
  }

  /// Optimistic: the row leaves the list immediately, and comes back if the
  /// backend refuses.
  Future<void> ignore(String id) async {
    final snapshot = _snapshot();
    _removeEverywhere(id);
    notifyListeners();
    try {
      await repo.ignore(id);
      unawaited(refreshOverview());
    } on ApiException catch (e) {
      _restore(snapshot);
      showToast(e.message);
    }
  }

  Future<void> unignore(String id) async {
    try {
      await repo.unignore(id);
      await Future.wait([refreshAlerts(), refreshOverview()]);
    } on ApiException catch (e) {
      showToast(e.message);
    }
  }

  Future<void> silence(String id, {int minutes = 60}) async {
    final snapshot = _snapshot();
    _removeEverywhere(id);
    notifyListeners();
    try {
      await repo.silence(id, minutes: minutes);
      unawaited(refreshOverview());
    } on ApiException catch (e) {
      _restore(snapshot);
      showToast(e.message);
    }
  }

  /// Returns null on success, or a message to show the user.
  Future<String?> restart(String alertId) async {
    if (!actionsEnabled) {
      return 'Restart is off on this server (v1 is notify-only)';
    }
    try {
      await repo.restart(alertId);
      unawaited(refreshActivity());
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Map<AlertFilter, List<Alert>> _snapshot() =>
      {for (final e in _byFilter.entries) e.key: [...e.value]};

  void _restore(Map<AlertFilter, List<Alert>> snapshot) {
    _byFilter
      ..clear()
      ..addAll(snapshot);
    notifyListeners();
  }

  // ---- incoming banner -----------------------------------------------------
  Alert? incoming;
  final Set<String> _seen = {};

  void setIncoming(Alert a) {
    if (_seen.contains(a.id)) return;
    _seen.add(a.id);
    incoming = a;
    notifyListeners();
  }

  void dismissIncoming() {
    incoming = null;
    notifyListeners();
  }

  // ---- mandate -------------------------------------------------------------
  MandateData mandate = const MandateData();
  bool mandateLoading = false;
  String? mandateError;
  Timer? _mandateSave;

  int get gate => mandate.gate;
  bool get pushAlerts => mandate.pushAlerts;
  bool get verifier => mandate.verifier;
  bool get groupLines => mandate.groupLines;
  bool get autoRestart => mandate.autoRestart;

  Future<void> refreshMandate() async {
    mandateLoading = true;
    notifyListeners();
    try {
      mandate = await repo.mandate();
      mandateError = null;
    } on ApiException catch (e) {
      mandateError = e.message;
    } finally {
      mandateLoading = false;
      notifyListeners();
    }
  }

  /// Applies locally at once and writes after a short pause, so dragging the
  /// gate slider is one PUT rather than forty.
  void editMandate(MandateData next, {bool immediate = false}) {
    final previous = mandate;
    mandate = next;
    notifyListeners();
    _mandateSave?.cancel();
    if (immediate) {
      unawaited(_saveMandate(previous));
    } else {
      _mandateSave = Timer(const Duration(milliseconds: 600), () => _saveMandate(previous));
    }
  }

  Future<void> _saveMandate(MandateData previous) async {
    try {
      mandate = await repo.putMandate(mandate);
      mandateError = null;
    } on ApiException catch (e) {
      mandate = previous; // e.g. 403 when auto_restart is off server-side
      mandateError = e.message;
      showToast(e.message);
    }
    notifyListeners();
  }

  void setGate(int v) => editMandate(mandate.copyWith(gate: v));

  // ---- activity ------------------------------------------------------------
  final List<ActivityEntry> _activity = [];
  bool activityLoading = false;
  bool activityHasMore = true;
  String? activityError;

  List<ActivityEntry> get activity => _activity;
  List<ActivityEntry> get recentActivity => _overview.activity;

  Future<void> refreshActivity() async {
    activityLoading = true;
    activityError = null;
    notifyListeners();
    try {
      final page = await repo.activity(limit: 50);
      _activity
        ..clear()
        ..addAll(page);
      activityHasMore = page.length == 50;
    } on ApiException catch (e) {
      activityError = e.message;
    } finally {
      activityLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreActivity() async {
    if (activityLoading || !activityHasMore || _activity.isEmpty) return;
    activityLoading = true;
    notifyListeners();
    try {
      final page = await repo.activity(before: _activity.last.createdAt, limit: 50);
      _activity.addAll(page);
      activityHasMore = page.length == 50;
    } on ApiException catch (e) {
      activityError = e.message;
    } finally {
      activityLoading = false;
      notifyListeners();
    }
  }

  // ---- polling -------------------------------------------------------------
  Timer? _poll;
  AppLifecycleListener? _lifecycle;

  void startPolling() {
    _lifecycle ??= AppLifecycleListener(
      onResume: () {
        _startTimer();
        unawaited(refreshAll());
        logs.start();
      },
      onPause: () {
        _poll?.cancel();
        _poll = null;
        logs.stop();
      },
    );
    _startTimer();
  }

  void _startTimer() {
    _poll ??= Timer.periodic(AppConfig.pollInterval, (_) => refreshAll());
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  Future<void> refreshAll() async {
    if (startPoint != StartPoint.home) return;
    await Future.wait([refreshOverview(), refreshAlerts()]);
  }

  // ---- live logs -----------------------------------------------------------
  static const _bufferSize = 400;
  final List<LogEntry> _logBuffer = [];
  bool paused = false;
  LogFilter logFilter = const LogFilter();
  StreamSubscription<LogEntry>? _logSub;
  StreamSubscription<LogStreamStatus>? _logStatusSub;
  LogStreamStatus logStatus = LogStreamStatus.idle;

  List<LogEntry> get logLines => _logBuffer;
  bool get hasLogs => _logBuffer.isNotEmpty;

  List<LogEntry> visibleLogs({int limit = 60}) {
    final out = <LogEntry>[];
    for (var i = _logBuffer.length - 1; i >= 0 && out.length < limit; i--) {
      if (logFilter.matches(_logBuffer[i])) out.add(_logBuffer[i]);
    }
    return out; // newest first
  }

  LogEntry? get newestLog => _logBuffer.isEmpty ? null : _logBuffer.last;

  /// Idempotent; the shell calls it whenever the player becomes visible.
  void startStreaming() {
    _logSub ??= logs.lines.listen((line) {
      if (paused) return;
      _logBuffer.add(line);
      if (_logBuffer.length > _bufferSize) _logBuffer.removeAt(0);
      notifyListeners();
    });
    _logStatusSub ??= logs.status.listen((s) {
      logStatus = s;
      notifyListeners();
    });
    logs.start();
  }

  void setPaused(bool v) {
    paused = v;
    notifyListeners();
  }

  void setLogFilter(LogFilter f) {
    logFilter = f;
    notifyListeners();
  }

  // ---- toast (rendered above every route) ----------------------------------
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
    _poll?.cancel();
    _lifecycle?.dispose();
    _mandateSave?.cancel();
    _toastTimer?.cancel();
    _logSub?.cancel();
    _logStatusSub?.cancel();
    logs.dispose();
    push.dispose();
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
