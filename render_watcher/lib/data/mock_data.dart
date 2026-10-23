import 'models.dart';

/// Sample data until the FastAPI backend and Render Logs API are wired in.
abstract final class MockData {
  static const services = <RenderService>[
    RenderService(
      id: 'billing',
      name: 'billing-worker',
      shortName: 'billing',
      kind: ServiceKind.worker,
      region: 'Frankfurt',
      health: ServiceHealth.down,
      vitals: '112 err/h · OOMKilled · deploy 14m',
    ),
    RenderService(
      id: 'api',
      name: 'api-gateway',
      shortName: 'api',
      kind: ServiceKind.web,
      region: 'Oregon',
      health: ServiceHealth.degraded,
      vitals: 'p95 840ms · 502 rate 6.2%',
    ),
    RenderService(
      id: 'site',
      name: 'marketing-site',
      shortName: 'site',
      kind: ServiceKind.staticSite,
      region: 'Global',
      health: ServiceHealth.healthy,
      vitals: 'p95 12ms · cache hit 99%',
    ),
    RenderService(
      id: 'reports',
      name: 'nightly-reports',
      shortName: 'reports',
      kind: ServiceKind.cron,
      region: 'Oregon',
      health: ServiceHealth.healthy,
      vitals: 'last run 13:00 · 14.2s',
    ),
    RenderService(
      id: 'db',
      name: 'postgres-main',
      shortName: 'db',
      kind: ServiceKind.postgres,
      region: 'Oregon',
      health: ServiceHealth.healthy,
      vitals: 'conn 41/100 · disk 38%',
    ),
  ];

  static RenderService service(String id) =>
      services.firstWhere((s) => s.id == id, orElse: () => services.first);

  static const alerts = <Alert>[
    Alert(
      id: 'a1',
      code: '#A-1042',
      title: 'Crash loop detected',
      headline: 'billing-worker is crash-looping',
      serviceId: 'billing',
      severity: Severity.critical,
      confidence: 0.94,
      timeAgo: '2m',
      since: 'since 14:01',
      occurrences: 18,
      verified: true,
      summary: 'Exits on boot with OOMKilled. Memory hits the 512MB limit within 40s.',
      cause:
          'Each boot loads the full invoices table into one batch, so memory climbs '
          'from 380MB to the 512MB limit in about 40 seconds and the process is '
          'killed. It started with v2.14.0.',
      suggestion: 'Suggested: roll back to v2.13.2, or stream invoices in pages of 10k.',
      evidence: [
        EvidenceLine('14:02:11', LogLevel.err, 'Process exited with code 137 (', 'OOMKilled', ')'),
        EvidenceLine('14:02:09', LogLevel.wrn, 'Memory usage ', '498MB / 512MB'),
        EvidenceLine('14:01:52', LogLevel.inf, 'Loading ', '1,284,330 invoices', ' into batch'),
        EvidenceLine('14:01:31', LogLevel.inf, 'Starting billing-worker ', 'v2.14.0'),
      ],
    ),
    Alert(
      id: 'a2',
      code: '#A-1041',
      title: '5xx spike on /checkout',
      headline: 'Checkout is failing for 6% of requests',
      serviceId: 'api',
      severity: Severity.warning,
      confidence: 0.81,
      timeAgo: '6m',
      since: 'since 14:00',
      occurrences: 47,
      summary: '502 rate at 6.2%. Upstream billing-worker is unreachable.',
      cause:
          'api-gateway is healthy, but every /checkout call waits on billing-worker, '
          'which is down. Calls time out after 30s and return 502.',
      suggestion: 'This should clear once billing-worker is back. No action needed here.',
      evidence: [
        EvidenceLine('14:05:40', LogLevel.err, 'POST /checkout 502 ', 'upstream timeout', ' 30001ms'),
        EvidenceLine('14:05:12', LogLevel.wrn, 'retry 3/3 billing-worker:10000 ', 'ECONNREFUSED'),
      ],
    ),
    Alert(
      id: 'a3',
      code: '#A-1039',
      title: 'Unusual auth failures',
      headline: 'Login failures are 4× normal',
      serviceId: 'api',
      severity: Severity.warning,
      confidence: 0.58,
      timeAgo: '24m',
      since: 'since 13:42',
      occurrences: 213,
      summary: 'Failures spread across many IPs. Not sure why. Please take a look.',
      cause:
          'Failed logins jumped to 4× the usual rate across 180+ IPs. It could be '
          'credential stuffing, or the iOS 5.2 release sending a bad password hash. '
          'The evidence fits both.',
      suggestion: 'Check whether failures cluster on one app version before blocking IPs.',
      evidence: [
        EvidenceLine('13:44:02', LogLevel.wrn, 'POST /auth/login 401 ', 'invalid_password', ' ua=ios/5.2'),
        EvidenceLine('13:43:59', LogLevel.wrn, 'POST /auth/login 401 ', 'invalid_password', ' ua=web'),
      ],
    ),
    Alert(
      id: 'a4',
      code: '#A-1036',
      title: 'Slow report query',
      headline: 'Nightly report query took 14s',
      serviceId: 'reports',
      severity: Severity.info,
      confidence: 0.88,
      timeAgo: '1h',
      since: 'at 13:00',
      occurrences: 2,
      summary: 'Aggregation took 14.2s. An index on orders(created_at) would help.',
      cause: 'The aggregation scans the whole orders table because created_at has no index.',
      suggestion: 'Add an index on orders(created_at).',
      evidence: [
        EvidenceLine('13:00:14', LogLevel.wrn, 'Query took ', '14211ms', ': SELECT … FROM orders'),
      ],
    ),
    Alert(
      id: 'r1',
      code: '#A-1030',
      title: 'Deploy failed: build timeout',
      headline: 'A deploy timed out while building',
      serviceId: 'site',
      severity: Severity.resolved,
      confidence: 0.90,
      timeAgo: '3h',
      since: 'at 11:12',
      occurrences: 1,
      summary: 'Resolved by the next deploy 6 minutes later.',
      cause: 'The build step exceeded 15 minutes after a dependency cache miss.',
      suggestion: 'No action needed.',
      evidence: [EvidenceLine('11:12:40', LogLevel.err, 'Build exceeded ', '15m timeout')],
    ),
    Alert(
      id: 'r2',
      code: '#A-1027',
      title: 'Memory pressure',
      headline: 'api-gateway ran close to its memory limit',
      serviceId: 'api',
      severity: Severity.resolved,
      confidence: 0.77,
      timeAgo: '5h',
      since: 'at 09:30',
      occurrences: 9,
      summary: 'Settled after traffic dropped. Watching for a repeat.',
      cause: 'Heap grew during a traffic spike and returned to baseline afterwards.',
      suggestion: 'No action needed.',
      evidence: [EvidenceLine('09:31:02', LogLevel.wrn, 'Memory usage ', '470MB / 512MB')],
    ),
  ];

  static const activity = <ActivityEntry>[
    ActivityEntry('14:06', Actor.agent, 'Alert sent', 'Crash loop on billing-worker, 94% sure, verified.', 'evidence: 18 lines · #A-1042'),
    ActivityEntry('14:05', Actor.verifier, 'Verifier agreed', 'Tried a deploy-config and host explanation. Neither fit.', 'evidence: 18 lines'),
    ActivityEntry('14:00', Actor.agent, 'Alert sent', '5xx spike on api-gateway, 81% sure.', 'evidence: 47 lines · #A-1041'),
    ActivityEntry('13:44', Actor.agent, 'Asked for your call', 'Auth failure pattern at 58%, under your 75% gate.', 'evidence: 213 lines · #A-1039'),
    ActivityEntry('13:20', Actor.you, 'You ignored an alert', 'Slow report query on nightly-reports.', 'from: alert detail'),
    ActivityEntry('12:58', Actor.you, 'You changed the mandate', 'Restart service set to ask every time.', 'from: mandate'),
    ActivityEntry('11:18', Actor.agent, 'Marked resolved', 'marketing-site deploy recovered on its own.', '#A-1030'),
    ActivityEntry('09:12', Actor.you, 'You connected Render', 'Key ending ••••x7Q2. 5 services found.', 'from: onboarding'),
  ];

  /// Repeating log templates for the simulated live tail.
  static const logTemplates = <(LogLevel, String, String, bool)>[
    (LogLevel.inf, 'api', 'GET /health 200 3ms', false),
    (LogLevel.err, 'billing', 'Process exited with code 137 (OOMKilled)', true),
    (LogLevel.wrn, 'billing', 'Memory usage 501MB / 512MB', true),
    (LogLevel.inf, 'api', 'GET /api/products 200 41ms', false),
    (LogLevel.err, 'api', 'POST /checkout 502 upstream timeout 30001ms', true),
    (LogLevel.inf, 'billing', 'Starting billing-worker v2.14.0', false),
    (LogLevel.inf, 'site', 'GET / 200 (cache) 1ms', false),
    (LogLevel.dbg, 'api', 'cache hit products:list ttl=48s', false),
    (LogLevel.inf, 'billing', 'Loading 1,284,330 invoices into batch', true),
    (LogLevel.wrn, 'api', 'retry 3/3 billing-worker:10000 ECONNREFUSED', false),
    (LogLevel.inf, 'api', 'GET /api/cart 200 18ms', false),
    (LogLevel.inf, 'site', 'GET /pricing 200 (cache) 2ms', false),
  ];
}
