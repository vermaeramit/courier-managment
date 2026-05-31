import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_store.dart';

/// Thin REST client. Attaches the JWT and surfaces clean error messages.
class ApiClient {
  final AuthStore auth;
  ApiClient(this.auth);

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
    final text = res.body;
    final data = text.isEmpty ? null : jsonDecode(text);
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
