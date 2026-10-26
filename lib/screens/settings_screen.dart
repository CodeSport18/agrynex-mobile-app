import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/session.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  final Map<String, bool> _switches = {};
  final Map<String, TextEditingController> _numbers = {
    for (final key in settingLimits.keys) key: TextEditingController(),
  };
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Settings s) {
    _switches
      ..['live_view_enabled'] = s.liveViewEnabled
      ..['clips_enabled'] = s.clipsEnabled
      ..['snapshots_enabled'] = s.snapshotsEnabled;
    final values = {
      'auto_duration_s': s.autoDurationS,
      'manual_max_s': s.manualMaxS,
      'clip_pre_s': s.clipPreS,
      'clip_post_s': s.clipPostS,
      'alert_cooldown_s': s.alertCooldownS,
      'retention_days': s.retentionDays,
    };
    values.forEach((k, v) => _numbers[k]!.text = '$v');
    _loaded = true;
  }

  Future<void> _load() async {
    try {
      final s = await context.read<Session>().api.settings();
      if (mounted) setState(() => _fill(s));
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final s = await context.read<Session>().api.updateSettings({
        ..._switches,
        for (final e in _numbers.entries) e.key: int.parse(e.value.text),
      });
      if (mounted) {
        setState(() => _fill(s));
        showMessage(context, 'Settings saved');
      }
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<Session>().user?.isAdmin ?? false;

    Widget toggle(String key, String title, String subtitle) => SwitchListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          value: _switches[key] ?? false,
          onChanged: isAdmin ? (v) => setState(() => _switches[key] = v) : null,
        );

    Widget number(String key, String label) {
      final (low, high) = settingLimits[key]!;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextFormField(
          controller: _numbers[key],
          enabled: isAdmin,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label, helperText: '$low–$high', border: const OutlineInputBorder()),
          validator: (v) {
            final n = int.tryParse(v ?? '');
            return n == null || n < low || n > high ? 'Enter a number from $low to $high' : null;
          },
        ),
      );
    }

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  if (!isAdmin)
                    const Padding(padding: EdgeInsets.all(16), child: Text('Only an admin can change settings.')),
                  section('Video'),
                  toggle('live_view_enabled', 'Live view', 'Watch the camera from the app'),
                  toggle('clips_enabled', 'Alert clips', 'Save a short video with each alert'),
                  toggle('snapshots_enabled', 'Alert snapshots', 'Save a photo with each alert'),
                  number('clip_pre_s', 'Seconds of clip before the detection'),
                  number('clip_post_s', 'Seconds of clip after the detection'),
                  section('Siren and sprinkler'),
                  number('auto_duration_s', 'Seconds they run after a detection'),
                  number('manual_max_s', 'Longest they stay on when switched on by hand (seconds)'),
                  section('Alerts'),
                  number('alert_cooldown_s', 'Minimum seconds between alerts'),
                  number('retention_days', 'Days to keep alerts and their media'),
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save settings')),
                    ),
                ],
              ),
            ),
    );
  }
}
