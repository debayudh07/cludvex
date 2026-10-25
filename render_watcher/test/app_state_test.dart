import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:render_watcher/api/api_client.dart';
import 'package:render_watcher/api/repository.dart';
import 'package:render_watcher/data/models.dart';
import 'package:render_watcher/services/auth_service.dart';
import 'package:render_watcher/state/app_state.dart';

Alert makeAlert(
  String id, {
  Severity severity = Severity.critical,
  bool needsReview = false,
  int occurrences = 10,
  String serviceId = 'srv-1',
}) {
  final now = DateTime.utc(2026, 10, 25, 14);
  return Alert(
    id: id,
    code: '#A-$id',
    title: 'Crash loop',
    headline: 'Crash loop, likely OOM',
    serviceId: serviceId,
    serviceName: 'billing-worker',
    severity: severity,
    confidence: 0.9,
    occurrences: occurrences,
    summary: '',
    cause: '',
    suggestion: '',
    evidence: const [],
    needsReview: needsReview,
    firstSeen: now,
    lastSeen: now,
    createdAt: now,
  );
}

const service = RenderService(
  id: 'srv-1',
  name: 'billing-worker',
  kind: ServiceKind.worker,
  health: ServiceHealth.down,
  vitals: '112 err/h',
  watched: true,
);

/// Stands in for the HTTP layer. Every method records its call so the tests
/// can assert what the app actually asked the backend for.
class FakeRepository extends Repository {
  FakeRepository();

  final calls = <String>[];

  Me meResponse = const Me(
    uid: 'u1',
    renderConnected: true,
    watchedCount: 1,
    actionsEnabled: false,
    maxWatched: 3,
  );
  Overview overviewResponse = const Overview(
    services: [service],
    openAlerts: 2,
    critical: 1,
    warning: 1,
    yourCall: 1,
  );
  Map<AlertFilter, List<Alert>> alertsResponse = {};
  MandateData mandateResponse = const MandateData();
  List<ActivityEntry> activityResponse = [];

  /// Set to make the next mutating call fail.
  ApiException? failWith;

  @override
  Future<Me> me() async {
    calls.add('me');
    return meResponse;
  }

  @override
  Future<Overview> overview() async {
    calls.add('overview');
    return overviewResponse;
  }

  @override
  Future<List<Alert>> alerts(AlertFilter filter) async {
    calls.add('alerts:${filter.wire}');
    return [...?alertsResponse[filter]];
  }

  @override
  Future<Alert> alert(String id) async {
    calls.add('alert:$id');
    return makeAlert(id);
  }

  @override
  Future<Alert> ignore(String id) async {
    calls.add('ignore:$id');
    if (failWith != null) throw failWith!;
    return makeAlert(id);
  }

  @override
  Future<Alert> unignore(String id) async {
    calls.add('unignore:$id');
    if (failWith != null) throw failWith!;
    return makeAlert(id);
  }

  @override
  Future<Alert> silence(String id, {int minutes = 60}) async {
    calls.add('silence:$id:$minutes');
    if (failWith != null) throw failWith!;
    return makeAlert(id);
  }

  @override
  Future<void> restart(String id) async {
    calls.add('restart:$id');
    if (failWith != null) throw failWith!;
  }

  @override
  Future<MandateData> mandate() async {
    calls.add('mandate');
    return mandateResponse;
  }

  @override
  Future<MandateData> putMandate(MandateData m) async {
    calls.add('putMandate:gate=${m.gate},auto=${m.autoRestart}');
    if (failWith != null) throw failWith!;
    mandateResponse = m;
    return m;
  }

  @override
  Future<List<ActivityEntry>> activity({DateTime? before, int limit = 50}) async {
    calls.add('activity:before=${before?.toIso8601String()}');
    return activityResponse;
  }

  @override
  Future<List<RenderService>> setWatched(Iterable<String> ids) async {
    calls.add('setWatched:${ids.join(",")}');
    if (failWith != null) throw failWith!;
    return [service];
  }
}

void main() {
  late FakeRepository repo;
  late AppState state;

  setUp(() {
    repo = FakeRepository();
    state = AppState(repository: repo, auth: FakeAuth());
  });

  tearDown(() => state.dispose());

  group('alerts', () {
    test('refreshAlerts loads the current filter', () async {
      repo.alertsResponse = {
        AlertFilter.all: [makeAlert('a1'), makeAlert('a2', severity: Severity.resolved)],
      };
      await state.refreshAlerts();

      expect(repo.calls, contains('alerts:all'));
      expect(state.filteredAlerts, hasLength(2));
      expect(state.openAlerts, hasLength(1));
      expect(state.alertsError, isNull);
    });

    test('a non-default filter also keeps the "all" list warm for the counts',
        () async {
      repo.alertsResponse = {
        AlertFilter.all: [makeAlert('a1'), makeAlert('a2')],
        AlertFilter.critical: [makeAlert('a1')],
      };
      await state.refreshAlerts(AlertFilter.critical);

      expect(repo.calls, containsAllInOrder(['alerts:critical', 'alerts:all']));
      expect(state.allAlerts, hasLength(2));
    });

    test('setFilter switches and fetches the new filter once', () async {
      repo.alertsResponse = {AlertFilter.yourCall: [makeAlert('a1', needsReview: true)]};
      state.setFilter(AlertFilter.yourCall);
      await Future<void>.delayed(Duration.zero);

      expect(state.filter, AlertFilter.yourCall);
      expect(repo.calls, contains('alerts:your_call'));

      // Already cached: no second request.
      repo.calls.clear();
      state.setFilter(AlertFilter.all);
      state.setFilter(AlertFilter.yourCall);
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls.where((c) => c == 'alerts:your_call'), isEmpty);
    });

    test('a failure is surfaced, not thrown', () async {
      final broken = _ThrowingRepository(ApiException(0, 'offline'));
      final s = AppState(repository: broken, auth: FakeAuth());
      addTearDown(s.dispose);

      await s.refreshAlerts();
      expect(s.alertsError, 'offline');
      expect(s.filteredAlerts, isEmpty);
    });

    test('evidenceLineCount sums occurrences of open alerts only', () async {
      repo.alertsResponse = {
        AlertFilter.all: [
          makeAlert('a1', occurrences: 112),
          makeAlert('a2', occurrences: 8),
          makeAlert('a3', occurrences: 500, severity: Severity.resolved),
        ],
      };
      await state.refreshAlerts();
      expect(state.evidenceLineCount, 120);
    });
  });

  group('optimistic actions', () {
    setUp(() async {
      repo.alertsResponse = {AlertFilter.all: [makeAlert('a1'), makeAlert('a2')]};
      await state.refreshAlerts();
    });

    test('ignore removes the row and calls the backend', () async {
      await state.ignore('a1');
      expect(repo.calls, contains('ignore:a1'));
      expect(state.allAlerts.map((a) => a.id), ['a2']);
    });

    test('ignore rolls back and toasts when the backend refuses', () async {
      repo.failWith = ApiException(404, 'Alert not found');
      await state.ignore('a1');

      expect(state.allAlerts.map((a) => a.id), ['a1', 'a2']);
      expect(state.toast.value?.message, 'Alert not found');
    });

    test('silence passes the window and removes the row', () async {
      await state.silence('a1', minutes: 120);
      expect(repo.calls, contains('silence:a1:120'));
      expect(state.allAlerts.map((a) => a.id), ['a2']);
    });

    test('silence rolls back on failure', () async {
      repo.failWith = ApiException(409, 'Render is not connected');
      await state.silence('a1');
      expect(state.allAlerts, hasLength(2));
    });

    test('restart is refused locally when the server is notify-only', () async {
      final message = await state.restart('a1');
      expect(message, contains('notify-only'));
      expect(repo.calls.where((c) => c.startsWith('restart')), isEmpty);
    });

    test('restart goes through once the server allows actions', () async {
      repo.meResponse = const Me(
        uid: 'u1',
        renderConnected: true,
        watchedCount: 1,
        actionsEnabled: true,
        maxWatched: 3,
      );
      state.me = repo.meResponse;

      expect(await state.restart('a1'), isNull);
      expect(repo.calls, contains('restart:a1'));
    });

    test('a 403 from restart comes back as a message', () async {
      state.me = const Me(
        uid: 'u1',
        renderConnected: true,
        watchedCount: 1,
        actionsEnabled: true,
        maxWatched: 3,
      );
      repo.failWith = ApiException(403, 'Restart is disabled on this server');
      expect(await state.restart('a1'), 'Restart is disabled on this server');
    });
  });

  group('overview', () {
    test('carries the counters through to the shell', () async {
      await state.refreshOverview();
      expect(state.openAlertCount, 2);
      expect(state.criticalCount, 1);
      expect(state.yourCallCount, 1);
      expect(state.watchedServices.single.id, 'srv-1');
      expect(state.watched, {'srv-1'});
    });

    test('serviceById and serviceLabel resolve a watched service', () async {
      await state.refreshOverview();
      expect(state.serviceById('srv-1')?.name, 'billing-worker');
      expect(state.serviceLabel('srv-1'), 'billing');
      // An id the app has never seen still renders as something.
      expect(state.serviceLabel('srv-unknown'), 'srv-unknown');
    });
  });

  group('mandate', () {
    test('editMandate applies locally at once and writes immediately when asked',
        () async {
      await state.refreshMandate();
      state.editMandate(state.mandate.copyWith(gate: 85), immediate: true);

      expect(state.gate, 85); // visible before the request resolves
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, contains('putMandate:gate=85,auto=false'));
    });

    test('a debounced edit coalesces a slider drag into one PUT', () async {
      await state.refreshMandate();
      for (final v in [76, 80, 84, 88]) {
        state.editMandate(state.mandate.copyWith(gate: v));
      }
      expect(state.gate, 88);
      expect(repo.calls.where((c) => c.startsWith('putMandate')), isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(repo.calls.where((c) => c.startsWith('putMandate')), hasLength(1));
      expect(repo.calls.last, 'putMandate:gate=88,auto=false');
    });

    test('a rejected mandate reverts to the previous value', () async {
      await state.refreshMandate();
      repo.failWith = ApiException(403, 'Agent actions are disabled on this server');

      state.editMandate(state.mandate.copyWith(autoRestart: true), immediate: true);
      expect(state.autoRestart, isTrue); // optimistic
      await Future<void>.delayed(Duration.zero);

      expect(state.autoRestart, isFalse);
      expect(state.toast.value?.message, contains('disabled'));
    });
  });

  group('activity', () {
    test('pages with a before cursor and stops when a short page arrives',
        () async {
      repo.activityResponse = [
        for (var i = 0; i < 50; i++)
          ActivityEntry('14:0$i', Actor.agent, 'Alert sent', '', '',
              id: 'e$i', createdAt: DateTime.utc(2026, 10, 25, 14, 0, i)),
      ];
      await state.refreshActivity();
      expect(state.activity, hasLength(50));
      expect(state.activityHasMore, isTrue);

      repo.activityResponse = [
        ActivityEntry('13:00', Actor.you, 'You ignored an alert', '', '',
            id: 'old', createdAt: DateTime.utc(2026, 10, 25, 13)),
      ];
      await state.loadMoreActivity();

      expect(state.activity, hasLength(51));
      expect(state.activityHasMore, isFalse);
      expect(repo.calls.last, contains('before=2026-10-25T14:00:49'));
    });
  });

  group('incoming banner', () {
    test('shows an alert once and never re-raises the same id', () async {
      final a = makeAlert('a1');
      state.setIncoming(a);
      expect(state.incoming?.id, 'a1');

      state.dismissIncoming();
      state.setIncoming(a);
      expect(state.incoming, isNull);
    });
  });

  group('startPoint', () {
    test('a signed-out session always starts at sign-in', () {
      final s = AppState(repository: repo, auth: FakeAuth(isSignedIn: false));
      addTearDown(s.dispose);
      s.me = const Me(
        uid: 'u1',
        renderConnected: true,
        watchedCount: 2,
        actionsEnabled: false,
        maxWatched: 3,
      );
      expect(s.startPoint, StartPoint.signIn);
    });

    test('walks setup in order', () {
      expect(state.startPoint, StartPoint.signIn); // no /me yet

      state.me = const Me(
        uid: 'u1',
        renderConnected: false,
        watchedCount: 0,
        actionsEnabled: false,
        maxWatched: 3,
      );
      expect(state.startPoint, StartPoint.connectRender);

      state.me = state.me!.copyWith(renderConnected: true);
      expect(state.startPoint, StartPoint.pickServices);

      state.me = state.me!.copyWith(watchedCount: 2);
      expect(state.startPoint, StartPoint.home);
    });
  });

  group('AlertFilter', () {
    test('wire values match the backend Filter literal', () {
      expect([for (final f in AlertFilter.values) f.wire],
          ['all', 'critical', 'warning', 'your_call', 'resolved']);
    });
  });
}

/// Reports a session without touching Firebase, which is not initialised in
/// a plain `flutter test` run.
class FakeAuth extends AuthService {
  FakeAuth({this.isSignedIn = true});

  final bool isSignedIn;

  @override
  bool get signedIn => isSignedIn;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<void> signOut() async {}
}

/// Fails every read, to exercise the error paths.
class _ThrowingRepository extends Repository {
  _ThrowingRepository(this.error);

  final ApiException error;

  @override
  Future<List<Alert>> alerts(AlertFilter filter) async => throw error;

  @override
  Future<Overview> overview() async => throw error;

  @override
  Future<MandateData> mandate() async => throw error;

  @override
  Future<List<ActivityEntry>> activity({DateTime? before, int limit = 50}) async =>
      throw error;
}
