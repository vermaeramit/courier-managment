import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Offline-capable action queue. Status updates / POD / COD are enqueued locally
/// and flushed to the API when connectivity is available. Riders frequently lose
/// signal, so every write goes through here.
class SyncQueue extends ChangeNotifier {
  static const _key = 'offline_queue_v1';
  final ApiClient api;
  final List<QueuedAction> _pending = [];
  bool _flushing = false;

  SyncQueue(this.api) {
    // Auto-flush whenever connectivity returns.
    Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        flush();
      }
    });
  }

  int get pendingCount => _pending.length;
  List<QueuedAction> get pending => List.unmodifiable(_pending);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _pending
        ..clear()
        ..addAll(list.map(QueuedAction.fromJson));
    }
    notifyListeners();
    flush(); // attempt to drain anything left from a previous session
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_pending.map((a) => a.toJson()).toList()));
  }

  /// Enqueue an action and try to send immediately. If offline/failed, it stays
  /// queued and is retried on the next connectivity change or app launch.
  Future<void> enqueue(QueuedAction action) async {
    _pending.add(action);
    await _persist();
    notifyListeners();
    await flush();
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Drain the queue oldest-first. Stops on the first failure so ordering is kept.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      if (!await _isOnline()) return;

      while (_pending.isNotEmpty) {
        final action = _pending.first;
        try {
          await api.post(action.path, action.body);
          _pending.removeAt(0);
          await _persist();
          notifyListeners();
        } on ApiException catch (e) {
          // 4xx that isn't auth means the action is bad; drop it so the queue
          // doesn't get stuck forever. Network/5xx -> keep & retry later.
          if (e.statusCode >= 400 && e.statusCode < 500 && e.statusCode != 401) {
            _pending.removeAt(0);
            await _persist();
            notifyListeners();
          } else {
            break; // retry later
          }
        } catch (_) {
          break; // network error -> retry later
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
