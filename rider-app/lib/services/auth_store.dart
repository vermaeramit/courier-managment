import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Persists the JWT + current user across launches.
class AuthStore extends ChangeNotifier {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'auth_user';

  String? _token;
  AuthUser? _user;

  String? get token => _token;
  AuthUser? get user => _user;
  bool get isLoggedIn => _token != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (raw != null) _user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> save(String token, AuthUser user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }
}
