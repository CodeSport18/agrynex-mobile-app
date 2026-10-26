import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/realtime.dart';
import '../state/session.dart';
import '../widgets/alert_tile.dart';
import '../widgets/common.dart';
import 'alert_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<Alert> _alerts = [];
  String? _nextBefore;
  bool _loading = false;
  bool _loadedOnce = false;
  StreamSubscription<Alert>? _sub;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _sub = context.read<Realtime>().alerts.listen((alert) {
      setState(() {
        final i = _alerts.indexWhere((a) => a.id == alert.id);
        if (i >= 0) {
          _alerts[i] = alert;
        } else {
          _alerts.insert(0, alert);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final page = await context.read<Session>().api.alerts(before: reset ? null : _nextBefore);
      setState(() {
        if (reset) _alerts.clear();
        _alerts.addAll(page.alerts.where((a) => !_alerts.any((x) => x.id == a.id)));
        _nextBefore = page.nextBefore;
        _loadedOnce = true;
      });
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 300 && _nextBefore != null) _load();
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _alerts.length + 1,
            itemBuilder: (context, i) {
              if (i == _alerts.length) {
                if (_loading) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                }
                if (_loadedOnce && _alerts.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No alerts yet.')));
                }
                return const SizedBox.shrink();
              }
              final alert = _alerts[i];
              return AlertTile(
                alert: alert,
                onTap: () async {
                  final deleted = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => AlertDetailScreen(alert: alert)),
                  );
                  if (deleted == true) setState(() => _alerts.removeWhere((a) => a.id == alert.id));
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
