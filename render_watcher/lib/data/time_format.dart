/// The backend sends timestamps; the UI shows short human strings. One place
/// so "14m ago" reads the same on every screen.
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// `14:05:22`, in the device's local zone.
String clockTime(DateTime at) {
  final t = at.toLocal();
  return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

/// `now`, `14m ago`, `3h ago`, `2d ago`.
String timeAgo(DateTime at, {DateTime? from}) {
  final secs = (from ?? DateTime.now()).difference(at.toLocal()).inSeconds;
  if (secs < 45) return 'now';
  if (secs < 3600) return '${secs ~/ 60}m ago';
  if (secs < 86400) return '${secs ~/ 3600}h ago';
  return '${secs ~/ 86400}d ago';
}

/// `since 14:05`, for the duration line on an alert.
String sinceLabel(DateTime at) {
  final t = at.toLocal();
  return 'since ${_two(t.hour)}:${_two(t.minute)}';
}

/// `14m`, `3h 10m` — how long an incident has been running.
String duration(DateTime from, DateTime to) {
  final m = to.difference(from).inMinutes;
  if (m < 1) return 'under a minute';
  if (m < 60) return '${m}m';
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '${h}h' : '${h}h ${rest}m';
}
