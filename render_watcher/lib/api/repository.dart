import '../data/models.dart';
import 'api_client.dart';

enum AlertFilter { all, critical, warning, yourCall, resolved }

extension AlertFilterWire on AlertFilter {
  /// Matches the `Filter` literal in backend/app/routers/alerts.py.
  String get wire => switch (this) {
        AlertFilter.all => 'all',
        AlertFilter.critical => 'critical',
        AlertFilter.warning => 'warning',
        AlertFilter.yourCall => 'your_call',
        AlertFilter.resolved => 'resolved',
      };

  String get label => switch (this) {
        AlertFilter.all => 'All',
        AlertFilter.critical => 'Critical',
        AlertFilter.warning => 'Warning',
        AlertFilter.yourCall => 'Your call',
        AlertFilter.resolved => 'Resolved',
      };
}

/// One typed method per backend endpoint. Nothing here knows about widgets,
/// so it can be faked wholesale in tests.
class Repository {
  Repository({ApiClient? client}) : _c = client ?? ApiClient();

  final ApiClient _c;

  ApiClient get client => _c;

  // ---- account
  Future<Me> me() async => Me.fromJson(await _c.get('/me') as Map<String, dynamic>);

  Future<List<RenderService>> connectRender(String apiKey) async {
    final res = await _c.post('/render/connect', {'api_key': apiKey});
    return _services(res);
  }

  Future<void> disconnectRender() => _c.delete('/render/connect');

  Future<List<RenderService>> services() async => _services(await _c.get('/services'));

  Future<List<RenderService>> setWatched(Iterable<String> ids) async =>
      _services(await _c.put('/services/watched', {'ids': ids.toList()}));

  Future<MandateData> mandate() async =>
      MandateData.fromJson(await _c.get('/mandate') as Map<String, dynamic>);

  Future<MandateData> putMandate(MandateData m) async =>
      MandateData.fromJson(await _c.put('/mandate', m.toJson()) as Map<String, dynamic>);

  Future<void> addDevice(String token, String platform, String? timezone) =>
      _c.post('/devices', {'token': token, 'platform': platform, 'timezone': timezone});

  Future<void> removeDevice(String token) => _c.delete('/devices/$token');

  // ---- alerts
  Future<Overview> overview() async =>
      Overview.fromJson(await _c.get('/overview') as Map<String, dynamic>);

  Future<List<Alert>> alerts(AlertFilter filter) async {
    final res = await _c.get('/alerts', {'filter': filter.wire}) as List;
    return [for (final a in res) Alert.fromJson(a as Map<String, dynamic>)];
  }

  Future<Alert> alert(String id) async =>
      Alert.fromJson(await _c.get('/alerts/$id') as Map<String, dynamic>);

  Future<Alert> ignore(String id) async =>
      Alert.fromJson(await _c.post('/alerts/$id/ignore') as Map<String, dynamic>);

  Future<Alert> unignore(String id) async =>
      Alert.fromJson(await _c.post('/alerts/$id/unignore') as Map<String, dynamic>);

  Future<Alert> silence(String id, {int minutes = 60}) async =>
      Alert.fromJson(await _c.post('/alerts/$id/silence', {'minutes': minutes}) as Map<String, dynamic>);

  /// 403 unless the server runs with ACTIONS_ENABLED=true.
  Future<void> restart(String id) => _c.post('/alerts/$id/restart');

  Future<List<ActivityEntry>> activity({DateTime? before, int limit = 50}) async {
    final res = await _c.get('/activity', {
      'limit': '$limit',
      if (before != null) 'before': before.toUtc().toIso8601String(),
    }) as List;
    return [for (final a in res) ActivityEntry.fromJson(a as Map<String, dynamic>)];
  }

  List<RenderService> _services(dynamic res) =>
      [for (final s in res as List) RenderService.fromJson(s as Map<String, dynamic>)];
}
