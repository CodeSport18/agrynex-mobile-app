import 'package:agrynex/api/models.dart';
import 'package:agrynex/state/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server addresses are cleaned up', () {
    expect(normalizeServerUrl(' example.onrender.com/ '), 'https://example.onrender.com');
    expect(normalizeServerUrl('http://localhost:8000'), 'http://localhost:8000');
  });

  test('alert from server JSON', () {
    final alert = Alert.fromJson({
      'id': 'a1',
      'created_at': '2026-10-26T05:53:14.517000+00:00',
      'kinds': ['animal', 'human'],
      'detections': [
        {'kind': 'animal', 'label': 'dog', 'confidence': 0.9},
        {'kind': 'human', 'label': 'person', 'confidence': 0.8},
      ],
      'snapshot_status': 'ready',
      'snapshot_url': 'https://s3/snap.jpg',
      'clip_status': 'pending',
      'clip_url': null,
    });
    expect(alert.title, 'Dog, person');
    expect(alert.hasHuman, isTrue);
    expect(alert.clipUrl, isNull);
  });

  test('device status with outputs', () {
    final status = DeviceStatus.fromJson({
      'online': true,
      'last_seen': '2026-10-26T05:53:14+00:00',
      'state': {
        'system_on': true,
        'siren': {'on': true, 'manual': true, 'auto': false, 'off_at': 1792994379.75},
      },
    });
    expect(status.siren.on, isTrue);
    expect(status.siren.offAt, isNotNull);
    expect(status.sprinkler.on, isFalse);
  });
}
