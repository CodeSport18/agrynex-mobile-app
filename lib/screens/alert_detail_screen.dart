import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../api/models.dart';
import '../state/realtime.dart';
import '../state/session.dart';
import '../widgets/common.dart';

/// One alert's snapshot, clip and detections. Pops with true if it was deleted.
class AlertDetailScreen extends StatefulWidget {
  final Alert alert;

  const AlertDetailScreen({super.key, required this.alert});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  late Alert _alert = widget.alert;
  VideoPlayerController? _video;
  StreamSubscription<Alert>? _sub;

  @override
  void initState() {
    super.initState();
    // Media links expire, so fetch fresh ones.
    context.read<Session>().api.alert(_alert.id).then(_update).catchError((_) {});
    _sub = context.read<Realtime>().alerts.where((a) => a.id == _alert.id).listen(_update);
  }

  void _update(Alert alert) {
    if (!mounted) return;
    setState(() => _alert = alert);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _playClip() async {
    final url = _alert.clipUrl;
    if (url == null) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    setState(() => _video = controller);
    try {
      await controller.initialize();
      await controller.play();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        showMessage(context, "Couldn't play the clip");
        setState(() => _video = null);
      }
      controller.dispose();
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this alert and its media?', 'Delete')) return;
    if (!mounted) return;
    try {
      await context.read<Session>().api.deleteAlert(_alert.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  String _statusText(String status) =>
      {'pending': 'Uploading…', 'failed': 'Upload failed', 'none': 'Not recorded'}[status] ?? status;

  Widget _mediaBox(Widget child) => AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(color: Colors.black, child: Center(child: child)),
      );

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Scaffold(
      appBar: AppBar(
        title: Text(_alert.title),
        actions: [IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: _delete)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(formatTime(_alert.createdAt), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Clip', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (video != null && video.value.isInitialized)
            Column(
              children: [
                AspectRatio(aspectRatio: video.value.aspectRatio, child: VideoPlayer(video)),
                VideoProgressIndicator(video, allowScrubbing: true),
                IconButton(
                  iconSize: 36,
                  icon: Icon(video.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                  onPressed: () => video.value.isPlaying ? video.pause() : video.play(),
                ),
              ],
            )
          else if (video != null)
            _mediaBox(const CircularProgressIndicator())
          else if (_alert.clipStatus == 'ready')
            _mediaBox(IconButton(
              iconSize: 64,
              color: Colors.white,
              icon: const Icon(Icons.play_circle_outline),
              onPressed: _playClip,
            ))
          else
            _mediaBox(Text(_statusText(_alert.clipStatus), style: const TextStyle(color: Colors.white70))),
          const SizedBox(height: 16),
          Text('Snapshot', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_alert.snapshotUrl != null)
            InteractiveViewer(child: Image.network(_alert.snapshotUrl!))
          else
            _mediaBox(Text(_statusText(_alert.snapshotStatus), style: const TextStyle(color: Colors.white70))),
          const SizedBox(height: 16),
          Text('Detections', style: Theme.of(context).textTheme.titleSmall),
          for (final d in _alert.detections)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(d.kind == 'human' ? Icons.person : Icons.pets),
              title: Text(d.kind == 'human' ? 'Person' : d.label),
              trailing: Text('${(d.confidence * 100).round()}%'),
            ),
        ],
      ),
    );
  }
}
