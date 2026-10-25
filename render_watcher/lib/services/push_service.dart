import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../api/repository.dart';

/// Must match backend/app/notify.py ANDROID_CHANNEL and the
/// default_notification_channel_id in AndroidManifest.xml.
const pushChannelId = 'critical_alerts';

/// Firestore/FCM wake-ups that arrive while the app is terminated. Registered
/// from main() before runApp. Kept deliberately empty: the backend's payload
/// already carries a notification for the system tray on iOS, and on Android
/// the tray entry is posted by the channel above, so there is nothing to do
/// here beyond letting the isolate start.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// What the app needs out of a push: which alert to open, and a nudge to
/// refetch. The payload fields are set in backend/app/notify.py.
class PushAlert {
  const PushAlert({required this.alertId, this.title, this.body, this.severity});

  factory PushAlert.fromData(Map<String, dynamic> data) => PushAlert(
        alertId: data['alert_id'] as String? ?? '',
        title: data['title'] as String?,
        body: data['body'] as String?,
        severity: data['severity'] as String?,
      );

  final String alertId;
  final String? title;
  final String? body;
  final String? severity;

  bool get isValid => alertId.isNotEmpty;
}

class PushService {
  PushService(this._repo, {FirebaseMessaging? messaging}) : _injected = messaging;

  final Repository _repo;
  final FirebaseMessaging? _injected;

  /// Resolved lazily: touching FirebaseMessaging.instance before
  /// Firebase.initializeApp throws, and AppState is built before that in
  /// tests.
  FirebaseMessaging get _fm => _injected ?? FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();

  /// A push landed while the app was in the foreground: refetch.
  final _received = StreamController<PushAlert>.broadcast();

  /// The user tapped a notification: open this alert.
  final _opened = StreamController<PushAlert>.broadcast();

  Stream<PushAlert> get received => _received.stream;
  Stream<PushAlert> get opened => _opened.stream;

  final _subs = <StreamSubscription<dynamic>>[];
  String? _token;
  bool _started = false;

  /// Safe to call on every sign-in; later calls only re-register the token.
  Future<void> start() async {
    if (_started) {
      await _registerToken();
      return;
    }
    _started = true;

    await _fm.requestPermission(alert: true, badge: true, sound: true);
    await _initLocal();

    // Subscribe before register(): the id arrives on onRegistered, which can
    // fire as soon as registration completes.
    _subs.add(_fm.onRegistered.listen((id) {
      _token = id;
      unawaited(_register(id));
    }));
    _subs.add(_fm.onUnregistered.listen((_) => _token = null));
    await _registerToken();

    _subs.add(FirebaseMessaging.onMessage.listen(_onForeground));
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final p = PushAlert.fromData(m.data);
      if (p.isValid) _opened.add(p);
    }));

    // Cold start from a notification tap.
    final initial = await _fm.getInitialMessage();
    if (initial != null) {
      final p = PushAlert.fromData(initial.data);
      if (p.isValid) _opened.add(p);
    }
  }

  Future<void> _initLocal() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) {
          _opened.add(PushAlert(alertId: id));
        }
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          pushChannelId,
          'Critical alerts',
          description: 'What the agent found in your Render logs.',
          importance: Importance.max,
        ));
  }

  /// The backend sends data-only messages on Android, so the app draws the
  /// tray entry itself while in the foreground.
  Future<void> _onForeground(RemoteMessage message) async {
    final p = PushAlert.fromData(message.data);
    if (!p.isValid) return;
    _received.add(p);
    await _local.show(
      id: p.alertId.hashCode & 0x7fffffff,
      title: p.title ?? 'Render Watcher',
      body: p.body ?? '',
      payload: p.alertId,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannelId,
          'Critical alerts',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// firebase_messaging 17 registers the app instance and reports a Firebase
  /// Installation ID on [FirebaseMessaging.onRegistered]. firebase-admin 7
  /// accepts an FID anywhere it accepts a registration token, so the
  /// backend's send_each_for_multicast works unchanged.
  Future<void> _registerToken() async {
    try {
      await _fm.register();
    } catch (e) {
      debugPrint('push: FCM registration failed ($e)');
    }
  }

  Future<void> _register(String token) async {
    String? tz;
    try {
      tz = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      tz = null; // backend falls back to UTC
    }
    try {
      await _repo.addDevice(token, _platform, tz);
    } catch (e) {
      // Not fatal: alerts still show in-app, just not as pushes.
      debugPrint('push: device registration failed ($e)');
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// Called on sign-out so the previous account stops receiving this device's
  /// alerts.
  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;
    try {
      await _repo.removeDevice(token);
    } catch (_) {
      // The account may already be gone; nothing useful to do.
    }
    _token = null;
  }

  /// The registered id, for diagnostics.
  String? get deviceId => _token;

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _received.close();
    _opened.close();
  }
}
