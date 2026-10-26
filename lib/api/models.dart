class User {
  final String id;
  final String email;
  final String name;
  final String role;

  User({required this.id, required this.email, required this.name, required this.role});

  bool get isAdmin => role == 'admin';
  String get displayName => name.isNotEmpty ? name : email;

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        email: j['email'] as String,
        name: (j['name'] as String?) ?? '',
        role: j['role'] as String,
      );
}

class Settings {
  final bool systemOn;
  final bool liveViewEnabled;
  final bool clipsEnabled;
  final bool snapshotsEnabled;
  final int autoDurationS;
  final int manualMaxS;
  final int clipPreS;
  final int clipPostS;
  final int alertCooldownS;
  final int retentionDays;

  Settings({
    required this.systemOn,
    required this.liveViewEnabled,
    required this.clipsEnabled,
    required this.snapshotsEnabled,
    required this.autoDurationS,
    required this.manualMaxS,
    required this.clipPreS,
    required this.clipPostS,
    required this.alertCooldownS,
    required this.retentionDays,
  });

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        systemOn: j['system_on'] as bool,
        liveViewEnabled: j['live_view_enabled'] as bool,
        clipsEnabled: j['clips_enabled'] as bool,
        snapshotsEnabled: j['snapshots_enabled'] as bool,
        autoDurationS: j['auto_duration_s'] as int,
        manualMaxS: j['manual_max_s'] as int,
        clipPreS: j['clip_pre_s'] as int,
        clipPostS: j['clip_post_s'] as int,
        alertCooldownS: j['alert_cooldown_s'] as int,
        retentionDays: j['retention_days'] as int,
      );
}

/// Limits the server enforces for each number setting.
const settingLimits = {
  'auto_duration_s': (1, 600),
  'manual_max_s': (10, 3600),
  'clip_pre_s': (0, 15),
  'clip_post_s': (1, 30),
  'alert_cooldown_s': (0, 3600),
  'retention_days': (1, 365),
};

/// The siren or sprinkler, as the Pi reports it.
class OutputState {
  final bool on;
  final bool manual;
  final bool auto;
  final DateTime? offAt;

  OutputState({required this.on, required this.manual, required this.auto, this.offAt});

  static OutputState fromJson(dynamic j) {
    if (j is! Map) return OutputState(on: false, manual: false, auto: false);
    final offAt = j['off_at'] as num?;
    return OutputState(
      on: j['on'] == true,
      manual: j['manual'] == true,
      auto: j['auto'] == true,
      offAt: offAt == null ? null : DateTime.fromMillisecondsSinceEpoch((offAt * 1000).round()),
    );
  }
}

class DeviceStatus {
  final bool online;
  final DateTime? lastSeen;
  final bool systemOn;
  final bool cameraOk;
  final DateTime? lastDetectionAt;
  final OutputState siren;
  final OutputState sprinkler;

  DeviceStatus({
    required this.online,
    required this.lastSeen,
    required this.systemOn,
    required this.cameraOk,
    required this.lastDetectionAt,
    required this.siren,
    required this.sprinkler,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> j) {
    final state = (j['state'] as Map?) ?? {};
    return DeviceStatus(
      online: j['online'] == true,
      lastSeen: _date(j['last_seen']),
      systemOn: state['system_on'] == true,
      cameraOk: state['camera_ok'] != false,
      lastDetectionAt: _date(state['last_detection_at']),
      siren: OutputState.fromJson(state['siren']),
      sprinkler: OutputState.fromJson(state['sprinkler']),
    );
  }
}

class Snapshot {
  final DeviceStatus device;
  final Settings settings;

  Snapshot(this.device, this.settings);

  factory Snapshot.fromJson(Map<String, dynamic> j) => Snapshot(
        DeviceStatus.fromJson(Map<String, dynamic>.from(j['device'] as Map)),
        Settings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)),
      );
}

class Detection {
  final String kind;
  final String label;
  final double confidence;

  Detection({required this.kind, required this.label, required this.confidence});

  factory Detection.fromJson(Map j) => Detection(
        kind: j['kind'] as String,
        label: j['label'] as String,
        confidence: (j['confidence'] as num).toDouble(),
      );
}

class Alert {
  final String id;
  final DateTime createdAt;
  final List<String> kinds;
  final List<Detection> detections;
  final String snapshotStatus;
  final String? snapshotUrl;
  final String clipStatus;
  final String? clipUrl;

  Alert({
    required this.id,
    required this.createdAt,
    required this.kinds,
    required this.detections,
    required this.snapshotStatus,
    required this.snapshotUrl,
    required this.clipStatus,
    required this.clipUrl,
  });

  /// For example "dog, person".
  String get title {
    final labels = <String>{for (final d in detections) d.kind == 'human' ? 'person' : d.label};
    final text = labels.join(', ');
    return text.isEmpty ? 'Detection' : text[0].toUpperCase() + text.substring(1);
  }

  bool get hasHuman => kinds.contains('human');

  factory Alert.fromJson(Map j) => Alert(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        kinds: List<String>.from(j['kinds'] as List),
        detections: [for (final d in j['detections'] as List) Detection.fromJson(d as Map)],
        snapshotStatus: j['snapshot_status'] as String,
        snapshotUrl: j['snapshot_url'] as String?,
        clipStatus: j['clip_status'] as String,
        clipUrl: j['clip_url'] as String?,
      );
}

DateTime? _date(dynamic value) => value is String ? DateTime.parse(value).toLocal() : null;
