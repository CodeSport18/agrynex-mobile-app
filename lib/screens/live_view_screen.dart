import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/realtime.dart';

/// Shows live frames from the Pi. The Pi only streams while this screen is open.
class LiveViewScreen extends StatefulWidget {
  const LiveViewScreen({super.key});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen> {
  late final Realtime _realtime = context.read<Realtime>();

  @override
  void initState() {
    super.initState();
    _realtime.startLive();
  }

  @override
  void dispose() {
    _realtime.stopLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<Realtime>().snapshot;
    final String? problem = snapshot == null
        ? null
        : !snapshot.settings.liveViewEnabled
            ? 'Live view is turned off in Settings'
            : !snapshot.device.online
                ? 'The Raspberry Pi is offline'
                : !snapshot.settings.systemOn
                    ? 'The system is off, so the camera is paused'
                    : null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live view'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: problem != null
            ? Text(problem, style: const TextStyle(color: Colors.white70))
            : ValueListenableBuilder<Uint8List?>(
                valueListenable: _realtime.frame,
                builder: (context, frame, _) => frame == null
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Waiting for video…', style: TextStyle(color: Colors.white70)),
                        ],
                      )
                    : InteractiveViewer(
                        maxScale: 4,
                        // gaplessPlayback avoids a flash between frames.
                        child: Image.memory(frame, gaplessPlayback: true, fit: BoxFit.contain),
                      ),
              ),
      ),
    );
  }
}
