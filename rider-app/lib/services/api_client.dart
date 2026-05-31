import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_store.dart';

/// Thin REST client. Attaches the JWT and surfaces clean error messages.
class ApiClient {
  final AuthStore auth;

  ApiClient(this.auth) {
    // Never send a bearer token over cleartext in a release build. Cleartext
    // http:// is allowed only in debug/profile (emulator/LAN testing).
    if (kReleaseMode && !AppConfig.apiBaseUrl.startsWith('https://')) {
      throw StateError(
          'API_BASE_URL must use https:// in release builds (got "${AppConfig.apiBaseUrl}").');
    }
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> _headers() {
    final h = {'Content-Type': 'application/json'};
    final token = auth.token;
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Future<dynamic> get(String path) async {
    final res = await http.get(_uri(path), headers: _headers());
    return _decode(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(_uri(path), headers: _headers(), body: jsonEncode(body));
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    // A 401 means the token is dead — force a logout so the rider re-authenticates
    // instead of silently retrying forever with an invalid token.
    if (res.statusCode == 401) {
      unawaited(auth.clear());
      throw ApiException('Session expired. Please sign in again.', 401);
    }

    final text = res.body;
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = null; // tolerate non-JSON error bodies (proxy/gateway pages)
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    final message = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'Request failed (${res.statusCode})';
    throw ApiException(message, res.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
