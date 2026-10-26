// Walks through the whole app at a watchable pace, for a demo recording.
//
// Needs a running cloud server with demo data and a connected Pi. See
// integration_test/demo/README.md. Run with:
//   flutter test integration_test/app_test.dart -d <simulator> --dart-define=SERVER_URL=http://localhost:8000
import 'package:agrynex/main.dart' as app;
import 'package:agrynex/widgets/alert_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const email = String.fromEnvironment('DEMO_EMAIL', defaultValue: 'admin@example.com');
const password = String.fromEnvironment('DEMO_PASSWORD', defaultValue: 'admin-pass-1');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Render every frame in real time so animations look right on video.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('demo walkthrough', timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    // Start signed out.
    await const FlutterSecureStorage().deleteAll();
    app.main();
    await waitFor(tester, find.text('Sign in'));
    await hold(tester, 2);

    // Sign in.
    await typeInto(tester, find.widgetWithText(TextFormField, 'Email'), email);
    await typeInto(tester, find.widgetWithText(TextFormField, 'Password'), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(tester, 0.6);
    await tapOn(tester, find.widgetWithText(FilledButton, 'Sign in'));

    // Dashboard: the Pi is online.
    await waitFor(tester, find.text('Online · watching'));
    await hold(tester, 3);

    // Person detection off and back on. The switch moves once the server confirms.
    final person = find.widgetWithText(SwitchListTile, 'Person detection');
    Finder personSwitch(bool on) =>
        find.descendant(of: person, matching: find.byWidgetPredicate((w) => w is Switch && w.value == on));
    await tapOn(tester, person);
    await waitFor(tester, personSwitch(false));
    await hold(tester, 2);
    await tapOn(tester, person);
    await waitFor(tester, personSwitch(true));
    await hold(tester, 1);

    // Siren and sprinkler, switched by hand.
    for (final name in ['Siren', 'Sprinkler']) {
      final tile = find.widgetWithText(SwitchListTile, name);
      await tapOn(tester, tile);
      await waitFor(tester, find.descendant(of: tile, matching: find.textContaining('Switched on by hand')));
      await hold(tester, 2.5);
      await tapOn(tester, tile);
      await waitFor(tester, find.descendant(of: tile, matching: find.text('Off')));
      await hold(tester, 1);
    }

    // Live view.
    await tapOn(tester, find.text('Watch the camera now'));
    await waitFor(tester, find.byType(InteractiveViewer));
    await hold(tester, 7);
    await tapOn(tester, find.byTooltip('Back'));
    await hold(tester, 1.5);

    // Alerts, then one alert's clip.
    await tapOn(tester, navItem('Alerts'));
    await waitFor(tester, find.byType(AlertTile));
    await hold(tester, 2.5);
    await tapOn(tester, find.byType(AlertTile).first);
    await waitFor(tester, find.byIcon(Icons.play_circle_outline));
    await hold(tester, 2);
    await tapOn(tester, find.byIcon(Icons.play_circle_outline));
    await waitFor(tester, find.byIcon(Icons.pause_circle));
    await hold(tester, 8);
    await tapOn(tester, find.byTooltip('Back'));
    await hold(tester, 1);
    await slowScroll(tester, find.byType(ListView), -500);
    await hold(tester, 1.5);

    // Settings.
    await tapOn(tester, navItem('Settings'));
    await waitFor(tester, find.text('Alert clips'));
    await hold(tester, 2);
    await slowScroll(tester, find.byType(ListView), -700);
    await hold(tester, 2);
    await slowScroll(tester, find.byType(ListView), 700);

    // Account and users.
    await tapOn(tester, navItem('Account'));
    await hold(tester, 1.5);
    await tapOn(tester, find.text('Users'));
    await waitFor(tester, find.byIcon(Icons.admin_panel_settings));
    await hold(tester, 3);
    await tapOn(tester, find.byTooltip('Back'));
    await hold(tester, 1);

    // System off and back on.
    await tapOn(tester, navItem('Dashboard'));
    await hold(tester, 1.5);
    final system = find.widgetWithText(SwitchListTile, 'System');
    await tapOn(tester, system);
    await waitFor(tester, find.text('Online · system off'));
    await hold(tester, 3);
    await tapOn(tester, system);
    await waitFor(tester, find.text('Online · watching'));
    await hold(tester, 3);
  });
}

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// Lets the app run for [seconds] of real time.
Future<void> hold(WidgetTester tester, double seconds) async {
  final end = DateTime.now().add(Duration(milliseconds: (seconds * 1000).round()));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder, {double timeout = 20}) async {
  final end = DateTime.now().add(Duration(milliseconds: (timeout * 1000).round()));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      final onScreen = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText());
      throw TestFailure('Timed out waiting for $finder. On screen: ${onScreen.join(' | ')}');
    }
    await hold(tester, 0.1);
  }
}

/// Taps with a visible touch circle, since simulated taps don't show one.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  final target = finder.first;
  await hold(tester, 0.3);
  final center = tester.getCenter(target);
  final overlay = tester.state<OverlayState>(find.byType(Overlay).first);
  final entry = OverlayEntry(builder: (_) => _TouchDot(center));
  overlay.insert(entry);
  await hold(tester, 0.25);
  await tester.tapAt(center);
  await hold(tester, 0.35);
  entry.remove();
  await hold(tester, 0.3);
}

/// Types one character at a time.
Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
  await tapOn(tester, field);
  for (var i = 1; i <= text.length; i++) {
    await tester.enterText(field, text.substring(0, i));
    await hold(tester, 0.06);
  }
  await hold(tester, 0.4);
}

Future<void> slowScroll(WidgetTester tester, Finder scrollable, double dy) async {
  const steps = 30;
  final gesture = await tester.startGesture(tester.getCenter(scrollable.first));
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await hold(tester, 0.03);
  }
  await gesture.up();
  await hold(tester, 0.5);
}

class _TouchDot extends StatelessWidget {
  final Offset center;

  const _TouchDot(this.center);

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.45),
            border: Border.all(color: Colors.black26, width: 2),
          ),
        ),
      ),
    );
  }
}
