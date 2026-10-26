import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../state/realtime.dart';
import '../state/session.dart';
import '../widgets/alert_tile.dart';
import '../widgets/common.dart';
import 'alert_detail_screen.dart';
import 'live_view_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Alert> _latest = [];
  final Set<String> _pending = {};
  StreamSubscription<Alert>? _alertSub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _refresh();
    _alertSub = context.read<Realtime>().alerts.listen(_onAlert);
    // Keeps the countdowns and "last seen" text current.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  void _onAlert(Alert alert) {
    setState(() {
      final i = _latest.indexWhere((a) => a.id == alert.id);
      if (i >= 0) {
        _latest[i] = alert;
      } else {
        _latest = [alert, ..._latest].take(5).toList();
      }
    });
  }

  Future<void> _refresh() async {
    final api = context.read<Session>().api;
    final realtime = context.read<Realtime>();
    try {
      final results = await Future.wait([api.status(), api.alerts(limit: 5)]);
      realtime.setSnapshot(results[0] as Snapshot);
      if (mounted) setState(() => _latest = (results[1] as AlertPage).alerts);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _control(String target, bool on) async {
    setState(() => _pending.add(target));
    try {
      await context.read<Session>().api.control(target, on);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      // The switch moves when the Pi reports its new state.
      if (mounted) setState(() => _pending.remove(target));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<Realtime>().snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Agrynex')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (snapshot == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else ...[
              _statusCard(snapshot),
              _controlsCard(snapshot),
              _liveCard(snapshot),
            ],
            const SizedBox(height: 8),
            Text('Latest alerts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_latest.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No alerts yet.')),
            for (final a in _latest)
              AlertTile(
                alert: a,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlertDetailScreen(alert: a)))
                    .then((deleted) {
                      if (deleted == true) setState(() => _latest.removeWhere((x) => x.id == a.id));
                    }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(Snapshot s) {
    final d = s.device;
    final colors = Theme.of(context).colorScheme;
    final (String label, Color color, String detail) = !d.online
        ? ('Offline', colors.outline, 'Last seen ${timeAgo(d.lastSeen)}')
        : !d.systemOn
        ? ('Online · system off', Colors.orange.shade700, 'Detection and camera are paused')
        : !s.settings.animalDetection && !s.settings.humanDetection
        ? ('Online · detection off', Colors.orange.shade700, 'Animal and person detection are both off')
        : (
            'Online · watching',
            colors.primary,
            !d.cameraOk
                ? "Camera isn't working"
                : d.lastDetectionAt == null
                ? 'No detections yet'
                : 'Last detection ${timeAgo(d.lastDetectionAt)}',
          );
    return Card(
      child: ListTile(
        leading: Icon(Icons.memory, color: color),
        title: const Text('Raspberry Pi'),
        subtitle: Text(detail),
        trailing: StatusPill(label, color),
      ),
    );
  }

  String _outputDetail(DeviceStatus d, OutputState o) {
    if (!d.online) return 'Pi is offline';
    if (!o.on) return 'Off';
    final how = o.manual ? 'Switched on by hand' : 'Running after a detection';
    if (o.offAt == null) return how;
    final left = o.offAt!.difference(DateTime.now()).inSeconds;
    return '$how, ${left < 0 ? 0 : left}s left';
  }

  Widget _controlsCard(Snapshot s) {
    final d = s.device;
    Widget row(String target, String title, String subtitle, bool value, bool enabled, IconData icon) {
      final busy = _pending.contains(target);
      return SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: enabled && !busy ? (on) => _control(target, on) : null,
      );
    }

    return Card(
      child: Column(
        children: [
          row(
            'system',
            'System',
            s.settings.systemOn ? 'Detection and camera on' : 'Detection and camera paused',
            s.settings.systemOn,
            true,
            Icons.power_settings_new,
          ),
          const Divider(height: 1),
          row(
            'animal_detection',
            'Animal detection',
            'Birds, cats, cows, dogs, horses, sheep',
            s.settings.animalDetection,
            true,
            Icons.pets,
          ),
          const Divider(height: 1),
          row(
            'human_detection',
            'Person detection',
            'People entering the farm',
            s.settings.humanDetection,
            true,
            Icons.directions_walk,
          ),
          const Divider(height: 1),
          row('siren', 'Siren', _outputDetail(d, d.siren), d.siren.on, d.online, Icons.campaign),
          const Divider(height: 1),
          row('sprinkler', 'Sprinkler', _outputDetail(d, d.sprinkler), d.sprinkler.on, d.online, Icons.water_drop),
        ],
      ),
    );
  }

  Widget _liveCard(Snapshot s) {
    final String? problem = !s.settings.liveViewEnabled
        ? 'Live view is turned off in Settings'
        : !s.device.online
        ? 'The Raspberry Pi is offline'
        : !s.settings.systemOn
        ? 'The system is off, so the camera is paused'
        : null;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.videocam),
        title: const Text('Live view'),
        subtitle: Text(problem ?? 'Watch the camera now'),
        trailing: const Icon(Icons.chevron_right),
        enabled: problem == null,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveViewScreen())),
      ),
    );
  }
}
