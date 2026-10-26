import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api/models.dart';

/// Live link to the cloud server: device status, new alerts and live video frames.
class Realtime extends ChangeNotifier {
  io.Socket? _socket;
  String? _token;
  Snapshot? snapshot;
  bool connected = false;
  int _watchers = 0;

  /// New and updated alerts as they arrive.
  final _alerts = StreamController<Alert>.broadcast();
  Stream<Alert> get alerts => _alerts.stream;

  /// The latest live video frame (JPEG), while someone is watching.
  final frame = ValueNotifier<Uint8List?>(null);

  void connect(String serverUrl, String token) {
    disconnect();
    final socket = io.io(
      '$serverUrl/client',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );
    socket.onConnect((_) {
      connected = true;
      // Watching survives a reconnect.
      if (_watchers > 0) socket.emit('live_start');
      notifyListeners();
    });
    socket.onDisconnect((_) {
      connected = false;
      notifyListeners();
    });
    socket.on('status', (data) {
      if (data is Map) {
        snapshot = Snapshot.fromJson(Map<String, dynamic>.from(data));
        notifyListeners();
      }
    });
    for (final event in ['alert', 'alert_updated']) {
      socket.on(event, (data) {
        if (data is Map) _alerts.add(Alert.fromJson(data));
      });
    }
    socket.on('frame', (data) {
      if (_watchers == 0) return;
      if (data is Uint8List) {
        frame.value = data;
      } else if (data is List<int>) {
        frame.value = Uint8List.fromList(data);
      } else if (data is ByteBuffer) {
        frame.value = data.asUint8List();
      }
    });
    socket.connect();
    _socket = socket;
    _token = token;
  }

  /// With [token], only disconnects if that's still the connection in use.
  void disconnect({String? token}) {
    if (token != null && token != _token) return;
    _token = null;
    _socket?.dispose();
    _socket = null;
    connected = false;
    snapshot = null;
    _watchers = 0;
    frame.value = null;
  }

  void setSnapshot(Snapshot s) {
    snapshot = s;
    notifyListeners();
  }

  void startLive() {
    _watchers++;
    if (_watchers == 1) _socket?.emit('live_start');
  }

  void stopLive() {
    if (_watchers == 0) return;
    _watchers--;
    if (_watchers == 0) {
      _socket?.emit('live_stop');
      frame.value = null;
    }
  }

  @override
  void dispose() {
    disconnect();
    _alerts.close();
    frame.dispose();
    super.dispose();
  }
}
