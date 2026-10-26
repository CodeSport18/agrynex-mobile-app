import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? status;

  ApiException(this.message, [this.status]);

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

class AlertPage {
  final List<Alert> alerts;
  final String? nextBefore;

  AlertPage(this.alerts, this.nextBefore);
}

/// Talks to the Agrynex cloud server's JSON API.
class ApiClient {
  final String baseUrl;
  String? token;

  /// Called when the server says the token is no longer valid.
  void Function()? onUnauthorized;

  ApiClient(this.baseUrl, {this.token});

  Future<Map<String, dynamic>> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await request.send().timeout(const Duration(seconds: 20)));
    } on Exception {
      throw ApiException("Can't reach the server. Check your internet connection.");
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      // Not JSON, for example a proxy error page.
    }
    if (res.statusCode == 401 && token != null) onUnauthorized?.call();
    if (res.statusCode >= 400) {
      throw ApiException((data['error'] as String?) ?? 'Request failed (${res.statusCode})', res.statusCode);
    }
    return data;
  }

  Future<(String, User)> login(String email, String password) async {
    final data = await _send('POST', '/api/auth/login', body: {'email': email, 'password': password});
    return (data['token'] as String, User.fromJson(data['user'] as Map<String, dynamic>));
  }

  Future<User> me() async {
    final data = await _send('GET', '/api/auth/me');
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Returns the new token, since the old one stops working.
  Future<String> changePassword(String current, String newPassword) async {
    final data = await _send('POST', '/api/auth/change-password',
        body: {'current_password': current, 'new_password': newPassword});
    return data['token'] as String;
  }

  Future<Snapshot> status() async => Snapshot.fromJson(await _send('GET', '/api/status'));

  Future<void> control(String target, bool on) => _send('POST', '/api/control', body: {'target': target, 'on': on});

  Future<Settings> settings() async {
    final data = await _send('GET', '/api/settings');
    return Settings.fromJson(data['settings'] as Map<String, dynamic>);
  }

  Future<Settings> updateSettings(Map<String, dynamic> changes) async {
    final data = await _send('PUT', '/api/settings', body: changes);
    return Settings.fromJson(data['settings'] as Map<String, dynamic>);
  }

  Future<AlertPage> alerts({String? before, int limit = 20}) async {
    final query = {'limit': '$limit', 'before': ?before};
    final data = await _send('GET', '/api/alerts?${Uri(queryParameters: query).query}');
    return AlertPage(
      [for (final a in data['alerts'] as List) Alert.fromJson(a as Map)],
      data['next_before'] as String?,
    );
  }

  Future<Alert> alert(String id) async {
    final data = await _send('GET', '/api/alerts/$id');
    return Alert.fromJson(data['alert'] as Map);
  }

  Future<void> deleteAlert(String id) => _send('DELETE', '/api/alerts/$id');

  Future<List<User>> users() async {
    final data = await _send('GET', '/api/users');
    return [for (final u in data['users'] as List) User.fromJson(u as Map<String, dynamic>)];
  }

  Future<void> createUser({required String email, required String password, required String name, required String role}) =>
      _send('POST', '/api/users', body: {'email': email, 'password': password, 'name': name, 'role': role});

  Future<void> resetPassword(String userId, String password) =>
      _send('POST', '/api/users/$userId/password', body: {'password': password});

  Future<void> deleteUser(String userId) => _send('DELETE', '/api/users/$userId');
}
