import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'time_format.dart';

/// Decoders are tolerant: an unknown string from a newer backend falls back to
/// the least alarming value rather than throwing mid-list.

enum Severity { critical, warning, info, resolved }

Severity severityFrom(String? s) => switch (s) {
      'critical' => Severity.critical,
      'warning' => Severity.warning,
      'resolved' => Severity.resolved,
      _ => Severity.info,
    };

extension SeverityStyle on Severity {
  String get label => switch (this) {
        Severity.critical => 'CRITICAL',
        Severity.warning => 'WARNING',
        Severity.info => 'INFO',
        Severity.resolved => 'RESOLVED',
      };

  Color get bar => switch (this) {
        Severity.critical => AppColors.critical,
        Severity.warning => AppColors.warning,
        Severity.info => AppColors.info,
        Severity.resolved => AppColors.handle,
      };

  Color get text => switch (this) {
        Severity.critical => AppColors.criticalText,
        Severity.warning => AppColors.warningText,
        Severity.info => AppColors.infoText,
        Severity.resolved => AppColors.okText,
      };
}

enum ServiceHealth { down, degraded, healthy }

ServiceHealth healthFrom(String? s) => switch (s) {
      'down' => ServiceHealth.down,
      'degraded' => ServiceHealth.degraded,
      _ => ServiceHealth.healthy,
    };

extension ServiceHealthStyle on ServiceHealth {
  String get label => switch (this) {
        ServiceHealth.down => 'Down',
        ServiceHealth.degraded => 'Degraded',
        ServiceHealth.healthy => 'Healthy',
      };

  Color get color => switch (this) {
        ServiceHealth.down => AppColors.critical,
        ServiceHealth.degraded => AppColors.warning,
        ServiceHealth.healthy => AppColors.ok,
      };

  Color get text => switch (this) {
        ServiceHealth.down => AppColors.criticalText,
        ServiceHealth.degraded => AppColors.warningText,
        ServiceHealth.healthy => AppColors.okText,
      };
}

enum ServiceKind { web, worker, staticSite, cron, postgres }

ServiceKind kindFrom(String? s) => switch (s) {
      'worker' => ServiceKind.worker,
      'static_site' => ServiceKind.staticSite,
      'cron' => ServiceKind.cron,
      'postgres' => ServiceKind.postgres,
      _ => ServiceKind.web,
    };

extension ServiceKindIcon on ServiceKind {
  IconData get icon => switch (this) {
        ServiceKind.web => Icons.public_rounded,
        ServiceKind.worker => Icons.memory_rounded,
        ServiceKind.staticSite => Icons.web_asset_rounded,
        ServiceKind.cron => Icons.schedule_rounded,
        ServiceKind.postgres => Icons.storage_rounded,
      };

  String get label => switch (this) {
        ServiceKind.web => 'Web Service',
        ServiceKind.worker => 'Background Worker',
        ServiceKind.staticSite => 'Static Site',
        ServiceKind.cron => 'Cron Job',
        ServiceKind.postgres => 'PostgreSQL',
      };
}

class RenderService {
  const RenderService({
    required this.id,
    required this.name,
    required this.kind,
    required this.health,
    required this.vitals,
    this.region,
    this.watched = false,
    String? shortName,
  }) : _shortName = shortName;  // ignore: prefer_initializing_formals

  factory RenderService.fromJson(Map<String, dynamic> j) => RenderService(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
        kind: kindFrom(j['kind'] as String?),
        region: j['region'] as String?,
        health: healthFrom(j['health'] as String?),
        vitals: j['vitals'] as String? ?? '',
        watched: j['watched'] as bool? ?? false,
      );

  final String id;
  final String name;
  final ServiceKind kind;

  /// Render reports no region for static sites and some private services.
  final String? region;
  final ServiceHealth health;

  /// One mono line of the numbers an on-call engineer glances at.
  final String vitals;
  final bool watched;
  final String? _shortName;

  /// Render has no short name, so derive one: `billing-worker` → `billing`.
  /// Chips and the radar need something that fits in a few characters.
  String get shortName {
    if (_shortName != null) return _shortName;
    final head = name.split(RegExp(r'[-_ ]')).first;
    final pick = head.length >= 3 ? head : name;
    return pick.length <= 10 ? pick : pick.substring(0, 10);
  }

  String get regionLabel => region ?? 'Global';

  RenderService copyWith({ServiceHealth? health, String? vitals, bool? watched}) => RenderService(
        id: id,
        name: name,
        kind: kind,
        region: region,
        health: health ?? this.health,
        vitals: vitals ?? this.vitals,
        watched: watched ?? this.watched,
        shortName: _shortName,
      );
}

enum LogLevel { err, wrn, inf, dbg }

LogLevel logLevelFrom(String? s) => switch (s) {
      'err' => LogLevel.err,
      'wrn' => LogLevel.wrn,
      'dbg' => LogLevel.dbg,
      _ => LogLevel.inf,
    };

extension LogLevelStyle on LogLevel {
  String get label => switch (this) {
        LogLevel.err => 'ERR',
        LogLevel.wrn => 'WRN',
        LogLevel.inf => 'INF',
        LogLevel.dbg => 'DBG',
      };

  Color get color => switch (this) {
        LogLevel.err => AppColors.criticalText,
        LogLevel.wrn => AppColors.warningText,
        LogLevel.inf => AppColors.infoText,
        LogLevel.dbg => AppColors.textFaint,
      };
}

class EvidenceLine {
  const EvidenceLine(this.time, this.level, this.before, this.highlight,
      [this.after = '']);

  factory EvidenceLine.fromJson(Map<String, dynamic> j) => EvidenceLine(
        clockTime(DateTime.parse(j['ts'] as String)),
        logLevelFrom(j['level'] as String?),
        j['before'] as String? ?? '',
        j['highlight'] as String? ?? '',
        j['after'] as String? ?? '',
      );

  final String time;
  final LogLevel level;
  final String before;
  final String highlight;
  final String after;
}

class Alert {
  Alert({
    required this.id,
    required this.code,
    required this.title,
    required this.headline,
    required this.serviceId,
    required this.severity,
    required this.confidence,
    required this.occurrences,
    required this.summary,
    required this.cause,
    required this.suggestion,
    required this.evidence,
    required this.firstSeen,
    required this.lastSeen,
    required this.createdAt,
    this.verified = false,
    this.state = 'open',
    bool? needsReview,
    this.serviceName,
  }) : _needsReview = needsReview;  // ignore: prefer_initializing_formals

  factory Alert.fromJson(Map<String, dynamic> j) {
    final raw = (j['evidence'] as List?) ?? const [];
    return Alert(
      id: j['id'] as String,
      code: j['code'] as String? ?? '',
      title: j['title'] as String? ?? 'Something looks wrong',
      headline: j['headline'] as String? ?? '',
      serviceId: j['service_id'] as String? ?? '',
      serviceName: j['service_name'] as String?,
      severity: severityFrom(j['severity'] as String?),
      state: j['state'] as String? ?? 'open',
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      occurrences: (j['occurrences'] as num?)?.toInt() ?? 0,
      summary: j['summary'] as String? ?? '',
      cause: j['cause'] as String? ?? '',
      suggestion: j['suggestion'] as String? ?? '',
      verified: j['verified'] as bool? ?? false,
      needsReview: j['needs_review'] as bool?,
      firstSeen: DateTime.parse(j['first_seen'] as String),
      lastSeen: DateTime.parse(j['last_seen'] as String),
      createdAt: DateTime.parse(j['created_at'] as String),
      evidence: [for (final e in raw) EvidenceLine.fromJson(e as Map<String, dynamic>)],
    );
  }

  final String id;
  final String code;
  final String title;
  final String headline;
  final String serviceId;
  final String? serviceName;
  final Severity severity;

  /// `open`, `ignored`, `silenced` or `resolved`, straight from the backend.
  final String state;
  final double confidence;
  final int occurrences;
  final String summary;
  final String cause;
  final String suggestion;
  final List<EvidenceLine> evidence;
  final bool verified;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final DateTime createdAt;
  final bool? _needsReview;

  bool get isOpen => severity != Severity.resolved;

  /// The agent was under the gate or the verifier disagreed: it's asking.
  bool get needsReview => isOpen && (_needsReview ?? confidence < 0.75);

  String get timeAgoLabel => timeAgo(createdAt);
  String get sinceText => sinceLabel(firstSeen);
  String get runningFor => duration(firstSeen, lastSeen);

  /// `GET /alerts` omits evidence; `GET /alerts/{id}` carries it.
  bool get hasEvidence => evidence.isNotEmpty;

  Alert copyWith({
    Severity? severity,
    String? state,
    int? occurrences,
    DateTime? lastSeen,
    List<EvidenceLine>? evidence,
  }) =>
      Alert(
        id: id,
        code: code,
        title: title,
        headline: headline,
        serviceId: serviceId,
        serviceName: serviceName,
        severity: severity ?? this.severity,
        state: state ?? this.state,
        confidence: confidence,
        occurrences: occurrences ?? this.occurrences,
        summary: summary,
        cause: cause,
        suggestion: suggestion,
        evidence: evidence ?? this.evidence,
        verified: verified,
        needsReview: _needsReview,
        firstSeen: firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
        createdAt: createdAt,
      );
}

/// Account status from GET /me.
class Me {
  const Me({
    required this.uid,
    required this.renderConnected,
    required this.watchedCount,
    required this.actionsEnabled,
    required this.maxWatched,
    this.email,
    this.keyLast4,
    this.githubLogin,
  });

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        uid: j['uid'] as String,
        email: j['email'] as String?,
        githubLogin: j['github_login'] as String?,
        renderConnected: j['render_connected'] as bool? ?? false,
        keyLast4: j['key_last4'] as String?,
        watchedCount: (j['watched_count'] as num?)?.toInt() ?? 0,
        actionsEnabled: j['actions_enabled'] as bool? ?? false,
        maxWatched: (j['max_watched_services'] as num?)?.toInt() ?? 3,
      );

  final String uid;
  final String? email;
  final String? githubLogin;
  final bool renderConnected;
  final String? keyLast4;
  final int watchedCount;
  final bool actionsEnabled;
  final int maxWatched;

  Me copyWith({bool? renderConnected, int? watchedCount, String? keyLast4}) => Me(
        uid: uid,
        email: email,
        githubLogin: githubLogin,
        renderConnected: renderConnected ?? this.renderConnected,
        keyLast4: keyLast4 ?? this.keyLast4,
        watchedCount: watchedCount ?? this.watchedCount,
        actionsEnabled: actionsEnabled,
        maxWatched: maxWatched,
      );
}

class MandateData {
  const MandateData({
    this.gate = 75,
    this.pushAlerts = true,
    this.verifier = true,
    this.groupLines = true,
    this.autoRestart = false,
    this.maxAlertsPerHour = 6,
    this.quietStart = '23:00',
    this.quietEnd = '07:00',
    this.timezone = 'UTC',
  });

  factory MandateData.fromJson(Map<String, dynamic> j) => MandateData(
        gate: (j['gate'] as num?)?.toInt() ?? 75,
        pushAlerts: j['push_alerts'] as bool? ?? true,
        verifier: j['verifier'] as bool? ?? true,
        groupLines: j['group_lines'] as bool? ?? true,
        autoRestart: j['auto_restart'] as bool? ?? false,
        maxAlertsPerHour: (j['max_alerts_per_hour'] as num?)?.toInt() ?? 6,
        quietStart: j['quiet_start'] as String?,
        quietEnd: j['quiet_end'] as String?,
        timezone: j['timezone'] as String? ?? 'UTC',
      );

  final int gate;
  final bool pushAlerts;
  final bool verifier;
  final bool groupLines;
  final bool autoRestart;
  final int maxAlertsPerHour;
  final String? quietStart;
  final String? quietEnd;
  final String timezone;

  Map<String, dynamic> toJson() => {
        'gate': gate,
        'push_alerts': pushAlerts,
        'verifier': verifier,
        'group_lines': groupLines,
        'auto_restart': autoRestart,
        'max_alerts_per_hour': maxAlertsPerHour,
        'quiet_start': quietStart,
        'quiet_end': quietEnd,
        'timezone': timezone,
      };

  MandateData copyWith({
    int? gate,
    bool? pushAlerts,
    bool? verifier,
    bool? groupLines,
    bool? autoRestart,
    int? maxAlertsPerHour,
    String? quietStart,
    String? quietEnd,
    String? timezone,
  }) =>
      MandateData(
        gate: gate ?? this.gate,
        pushAlerts: pushAlerts ?? this.pushAlerts,
        verifier: verifier ?? this.verifier,
        groupLines: groupLines ?? this.groupLines,
        autoRestart: autoRestart ?? this.autoRestart,
        maxAlertsPerHour: maxAlertsPerHour ?? this.maxAlertsPerHour,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        timezone: timezone ?? this.timezone,
      );
}

class Overview {
  const Overview({
    this.services = const [],
    this.activity = const [],
    this.openAlerts = 0,
    this.critical = 0,
    this.warning = 0,
    this.yourCall = 0,
  });

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
        services: [
          for (final s in (j['services'] as List?) ?? const [])
            RenderService.fromJson(s as Map<String, dynamic>),
        ],
        activity: [
          for (final a in (j['activity'] as List?) ?? const [])
            ActivityEntry.fromJson(a as Map<String, dynamic>),
        ],
        openAlerts: (j['open_alerts'] as num?)?.toInt() ?? 0,
        critical: (j['critical'] as num?)?.toInt() ?? 0,
        warning: (j['warning'] as num?)?.toInt() ?? 0,
        yourCall: (j['your_call'] as num?)?.toInt() ?? 0,
      );

  final List<RenderService> services;
  final List<ActivityEntry> activity;
  final int openAlerts;
  final int critical;
  final int warning;
  final int yourCall;
}

class LogEntry {
  const LogEntry({
    required this.index,
    required this.time,
    required this.level,
    required this.serviceId,
    required this.message,
    this.flagged = false,
  });

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        index: (j['index'] as num?)?.toInt() ?? 0,
        time: clockTime(DateTime.parse(j['time'] as String)),
        level: logLevelFrom(j['level'] as String?),
        serviceId: j['service_id'] as String? ?? '',
        message: j['message'] as String? ?? '',
        flagged: j['flagged'] as bool? ?? false,
      );

  final int index;
  final String time;
  final LogLevel level;
  final String serviceId;
  final String message;

  /// Lines the agent pulled into a diagnosis.
  final bool flagged;
}

enum Actor { agent, verifier, you }

Actor actorFrom(String? s) => switch (s) {
      'verifier' => Actor.verifier,
      'you' => Actor.you,
      _ => Actor.agent,
    };

class ActivityEntry {
  ActivityEntry(this.time, this.actor, this.action, this.detail, this.meta,
      {this.id = '', this.alertId, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  factory ActivityEntry.fromJson(Map<String, dynamic> j) {
    final at = DateTime.parse(j['created_at'] as String);
    return ActivityEntry(
      clockTime(at).substring(0, 5), // HH:mm is enough in the audit list
      actorFrom(j['actor'] as String?),
      j['action'] as String? ?? '',
      j['detail'] as String? ?? '',
      j['meta'] as String? ?? '',
      id: j['id'] as String? ?? '',
      alertId: j['alert_id'] as String?,
      createdAt: at,
    );
  }

  final String time;
  final Actor actor;
  final String action;
  final String detail;
  final String meta;
  final String id;
  final String? alertId;

  /// The `before` cursor for the next page of GET /activity.
  final DateTime createdAt;
}
