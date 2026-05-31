import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

/// Persists the JWT + current user across launches. The token and user are
/// sensitive, so they live in platform-backed secure storage (Android Keystore /
/// iOS Keychain), not plaintext SharedPreferences.
class AuthStore extends ChangeNotifier {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'auth_user';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _token;
  AuthUser? _user;

  String? get token => _token;
  AuthUser? get user => _user;
  bool get isLoggedIn => _token != null;

  Future<void> load() async {
    _token = await _storage.read(key: _tokenKey);
    final raw = await _storage.read(key: _userKey);
    if (raw != null) {
      try {
        _user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt/incompatible stored user -> treat as logged out.
        _token = null;
        _user = null;
      }
    }
    notifyListeners();
  }

  Future<void> save(String token, AuthUser user) async {
    _token = token;
    _user = user;
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
    notifyListeners();
  }

  Future<void> clear() async {
    if (_token == null && _user == null) return; // already cleared; avoid redundant notifies
    _token = null;
    _user = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    notifyListeners();
  }
}
