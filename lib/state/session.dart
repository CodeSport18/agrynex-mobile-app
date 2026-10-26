import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../config.dart';

/// Who is signed in, to which server. The token is kept in the phone's secure storage.
class Session extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  String serverUrl = defaultServerUrl;
  User? user;
  bool restoring = true;
  late ApiClient api = _makeApi(null);

  bool get signedIn => user != null;

  ApiClient _makeApi(String? token) => ApiClient(serverUrl, token: token)..onUnauthorized = _expired;

  Future<void> restore() async {
    try {
      serverUrl = await _storage.read(key: 'server_url') ?? defaultServerUrl;
      final token = await _storage.read(key: 'token');
      final userJson = await _storage.read(key: 'user');
      api = _makeApi(token);
      if (token != null && userJson != null) {
        user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        // Refresh in the background. If the server is unreachable, stay signed in.
        api.me().then(_saveUser).catchError((_) {});
      }
    } catch (_) {
      // Storage can fail after an app reinstall on iOS. Start signed out.
      user = null;
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> login(String server, String email, String password) async {
    final url = normalizeServerUrl(server);
    final client = ApiClient(url);
    final (token, signedInUser) = await client.login(email, password);
    serverUrl = url;
    api = _makeApi(token);
    await _storage.write(key: 'server_url', value: url);
    await _storage.write(key: 'token', value: token);
    await _saveUser(signedInUser);
  }

  Future<void> _saveUser(User u) async {
    user = u;
    await _storage.write(
      key: 'user',
      value: jsonEncode({'id': u.id, 'email': u.email, 'name': u.name, 'role': u.role}),
    );
    notifyListeners();
  }

  Future<void> changePassword(String current, String newPassword) async {
    final token = await api.changePassword(current, newPassword);
    api.token = token;
    await _storage.write(key: 'token', value: token);
    notifyListeners();
  }

  Future<void> logout() async {
    user = null;
    api = _makeApi(null);
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');
    notifyListeners();
  }

  void _expired() {
    if (user != null) logout();
  }
}

String normalizeServerUrl(String input) {
  var url = input.trim();
  if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'https://$url';
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}
