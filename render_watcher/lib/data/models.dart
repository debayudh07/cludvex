import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum Severity { critical, warning, info, resolved }

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
    required this.shortName,
    required this.kind,
    required this.region,
    required this.health,
    required this.vitals,
  });

  final String id;
  final String name;
  final String shortName;
  final ServiceKind kind;
  final String region;
  final ServiceHealth health;

  /// One mono line of the numbers an on-call engineer glances at.
  final String vitals;
}

enum LogLevel { err, wrn, inf, dbg }

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

  final String time;
  final LogLevel level;
  final String before;
  final String highlight;
  final String after;
}

class Alert {
  const Alert({
    required this.id,
    required this.code,
    required this.title,
    required this.headline,
    required this.serviceId,
    required this.severity,
    required this.confidence,
    required this.timeAgo,
    required this.since,
    required this.occurrences,
    required this.summary,
    required this.cause,
    required this.suggestion,
    required this.evidence,
    this.verified = false,
  });

  final String id;
  final String code;
  final String title;
  final String headline;
  final String serviceId;
  final Severity severity;
  final double confidence;
  final String timeAgo;
  final String since;
  final int occurrences;
  final String summary;
  final String cause;
  final String suggestion;
  final List<EvidenceLine> evidence;
  final bool verified;

  bool get isOpen => severity != Severity.resolved;
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

  final int index;
  final String time;
  final LogLevel level;
  final String serviceId;
  final String message;

  /// Lines the agent pulled into a diagnosis.
  final bool flagged;
}

enum Actor { agent, verifier, you }

class ActivityEntry {
  const ActivityEntry(this.time, this.actor, this.action, this.detail, this.meta);

  final String time;
  final Actor actor;
  final String action;
  final String detail;
  final String meta;
}
