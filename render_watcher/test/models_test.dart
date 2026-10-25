import 'package:flutter_test/flutter_test.dart';
import 'package:render_watcher/data/models.dart';

/// Fixtures mirror the shapes in backend/app/schemas.py. If one of these
/// fails after a backend change, the API contract moved.
void main() {
  group('RenderService.fromJson', () {
    test('maps a watched worker', () {
      final s = RenderService.fromJson({
        'id': 'srv-123',
        'name': 'billing-worker',
        'kind': 'worker',
        'region': 'frankfurt',
        'health': 'down',
        'vitals': '112 err/h · OOMKilled',
        'watched': true,
      });
      expect(s.id, 'srv-123');
      expect(s.kind, ServiceKind.worker);
      expect(s.health, ServiceHealth.down);
      expect(s.watched, isTrue);
      expect(s.shortName, 'billing');
    });

    test('static_site maps to staticSite and a null region reads as Global', () {
      final s = RenderService.fromJson({
        'id': 'srv-9',
        'name': 'marketing-site',
        'kind': 'static_site',
        'region': null,
        'health': 'healthy',
        'vitals': '',
      });
      expect(s.kind, ServiceKind.staticSite);
      expect(s.region, isNull);
      expect(s.regionLabel, 'Global');
      expect(s.watched, isFalse);
    });

    test('an unknown kind or health falls back rather than throwing', () {
      final s = RenderService.fromJson({
        'id': 'srv-1',
        'name': 'x',
        'kind': 'something_new',
        'region': 'oregon',
        'health': 'exploded',
        'vitals': '',
      });
      expect(s.kind, ServiceKind.web);
      expect(s.health, ServiceHealth.healthy);
    });

    test('shortName keeps a one-word name and truncates a long one', () {
      RenderService named(String name) => RenderService.fromJson(
          {'id': 'i', 'name': name, 'kind': 'web', 'health': 'healthy', 'vitals': ''});
      expect(named('api').shortName, 'api');
      expect(named('ab-worker').shortName, 'ab-worker'); // head too short to use
      expect(named('verylongsingleword').shortName, 'verylongsi');
    });
  });

  group('Alert.fromJson', () {
    Map<String, dynamic> payload({
      String severity = 'critical',
      bool needsReview = false,
      List<Map<String, dynamic>> evidence = const [],
    }) =>
        {
          'id': 'a1',
          'code': '#A-1042',
          'title': 'Crash loop detected',
          'headline': 'Crash loop, likely OOM',
          'service_id': 'srv-123',
          'service_name': 'billing-worker',
          'severity': severity,
          'state': 'open',
          'confidence': 0.91,
          'occurrences': 112,
          'summary': 'Restarting every 40s.',
          'cause': 'Memory ceiling.',
          'suggestion': 'Raise the instance size.',
          'verified': true,
          'needs_review': needsReview,
          'first_seen': '2026-10-25T14:05:00Z',
          'last_seen': '2026-10-25T14:19:00Z',
          'created_at': '2026-10-25T14:06:00Z',
          'evidence': evidence,
        };

    test('maps the list shape, which carries no evidence', () {
      final a = Alert.fromJson(payload());
      expect(a.id, 'a1');
      expect(a.code, '#A-1042');
      expect(a.serviceName, 'billing-worker');
      expect(a.severity, Severity.critical);
      expect(a.confidence, 0.91);
      expect(a.occurrences, 112);
      expect(a.verified, isTrue);
      expect(a.isOpen, isTrue);
      expect(a.hasEvidence, isFalse);
      expect(a.runningFor, '14m');
    });

    test('the backend decides needs_review, not the local gate', () {
      // 91% confidence would clear any gate, but the verifier disagreed.
      expect(Alert.fromJson(payload(needsReview: true)).needsReview, isTrue);
      expect(Alert.fromJson(payload()).needsReview, isFalse);
    });

    test('a resolved alert is not open and never asks for review', () {
      final a = Alert.fromJson(payload(severity: 'resolved', needsReview: true));
      expect(a.severity, Severity.resolved);
      expect(a.isOpen, isFalse);
      expect(a.needsReview, isFalse);
    });

    test('detail shape decodes evidence lines', () {
      final a = Alert.fromJson(payload(evidence: [
        {
          'ts': '2026-10-25T14:05:12Z',
          'level': 'err',
          'before': 'worker exited ',
          'highlight': 'OOMKilled',
          'after': ' (137)',
        },
      ]));
      expect(a.hasEvidence, isTrue);
      expect(a.evidence.single.level, LogLevel.err);
      expect(a.evidence.single.highlight, 'OOMKilled');
      expect(a.evidence.single.time, matches(r'^\d\d:\d\d:\d\d$'));
    });

    test('missing optional fields do not throw', () {
      final a = Alert.fromJson({
        'id': 'a2',
        'first_seen': '2026-10-25T14:00:00Z',
        'last_seen': '2026-10-25T14:00:00Z',
        'created_at': '2026-10-25T14:00:00Z',
      });
      expect(a.title, 'Something looks wrong');
      expect(a.confidence, 0);
      expect(a.occurrences, 0);
      expect(a.severity, Severity.info);
    });
  });

  group('Overview.fromJson', () {
    test('carries the counters and nests services and activity', () {
      final o = Overview.fromJson({
        'services': [
          {'id': 's1', 'name': 'api-gateway', 'kind': 'web', 'health': 'degraded', 'vitals': 'p95 840ms'},
        ],
        'open_alerts': 3,
        'critical': 1,
        'warning': 2,
        'your_call': 1,
        'activity': [
          {
            'id': 'e1',
            'actor': 'verifier',
            'action': 'Verifier agreed',
            'detail': 'Matches the restart pattern.',
            'meta': 'evidence: 112 lines',
            'created_at': '2026-10-25T14:07:00Z',
          },
        ],
      });
      expect(o.openAlerts, 3);
      expect(o.critical, 1);
      expect(o.warning, 2);
      expect(o.yourCall, 1);
      expect(o.services.single.health, ServiceHealth.degraded);
      expect(o.activity.single.actor, Actor.verifier);
      expect(o.activity.single.time, matches(r'^\d\d:\d\d$'));
    });

    test('an empty payload decodes to zeroes', () {
      final o = Overview.fromJson({});
      expect(o.services, isEmpty);
      expect(o.activity, isEmpty);
      expect(o.openAlerts, 0);
    });
  });

  group('Me.fromJson', () {
    test('maps the account and server capability flags', () {
      final me = Me.fromJson({
        'uid': 'u1',
        'email': 'dev@example.com',
        'github_login': 'octocat',
        'render_connected': true,
        'key_last4': 'x7Q2',
        'watched_count': 2,
        'actions_enabled': false,
        'max_watched_services': 3,
      });
      expect(me.renderConnected, isTrue);
      expect(me.keyLast4, 'x7Q2');
      expect(me.watchedCount, 2);
      expect(me.actionsEnabled, isFalse);
      expect(me.maxWatched, 3);
    });
  });

  group('MandateData', () {
    const json = {
      'gate': 80,
      'push_alerts': true,
      'verifier': false,
      'group_lines': true,
      'auto_restart': false,
      'max_alerts_per_hour': 12,
      'quiet_start': '23:00',
      'quiet_end': '07:00',
      'timezone': 'Asia/Kolkata',
    };

    test('decodes every field', () {
      final m = MandateData.fromJson(json);
      expect(m.gate, 80);
      expect(m.verifier, isFalse);
      expect(m.maxAlertsPerHour, 12);
      expect(m.timezone, 'Asia/Kolkata');
    });

    test('round-trips through toJson so PUT /mandate accepts it', () {
      expect(MandateData.fromJson(json).toJson(), json);
    });

    test('null quiet hours survive the round trip', () {
      final m = MandateData.fromJson({...json, 'quiet_start': null, 'quiet_end': null});
      expect(m.quietStart, isNull);
      expect(m.toJson()['quiet_end'], isNull);
    });
  });

  group('LogEntry.fromJson', () {
    test('maps a flagged error frame from the log socket', () {
      final e = LogEntry.fromJson({
        'index': 41,
        'time': '2026-10-25T14:05:22Z',
        'level': 'err',
        'service_id': 'srv-123',
        'message': 'worker exited OOMKilled',
        'flagged': true,
      });
      expect(e.index, 41);
      expect(e.level, LogLevel.err);
      expect(e.serviceId, 'srv-123');
      expect(e.flagged, isTrue);
      expect(e.time, matches(r'^\d\d:\d\d:\d\d$'));
    });
  });
}
