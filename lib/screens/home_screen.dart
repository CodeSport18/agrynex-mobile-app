import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/realtime.dart';
import '../state/session.dart';
import 'account_screen.dart';
import 'alerts_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late final Realtime _realtime = context.read<Realtime>();
  late final String _token;

  @override
  void initState() {
    super.initState();
    final session = context.read<Session>();
    _token = session.api.token!;
    _realtime.connect(session.serverUrl, _token);
  }

  @override
  void dispose() {
    // After a password change the new screen has already connected with the
    // new token, so leave that connection alone.
    _realtime.disconnect(token: _token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [DashboardScreen(), AlertsScreen(), SettingsScreen(), AccountScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}
