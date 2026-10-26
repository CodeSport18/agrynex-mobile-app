import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'state/realtime.dart';
import 'state/session.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Session()..restore()),
        ChangeNotifierProvider(create: (_) => Realtime()),
      ],
      child: const AgrynexApp(),
    ),
  );
}

class AgrynexApp extends StatelessWidget {
  const AgrynexApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F7D3B);
    return MaterialApp(
      title: 'Agrynex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const Root(),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!session.signedIn) return const LoginScreen();
    // A new token (after a password change) reconnects the live link.
    return HomeScreen(key: ValueKey(session.api.token));
  }
}
