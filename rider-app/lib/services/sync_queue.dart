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
  // After this many server (5xx) failures a single action is parked/dropped so it
  // can't block every later action in the FIFO forever (head-of-line blocking).
  static const _maxAttempts = 8;
  final ApiClient api;
  final List<QueuedAction> _pending = [];
  bool _flushing = false;
  bool _flushRequested = false; // set when flush() is called mid-flush

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
      _pending.clear();
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          try {
            _pending.add(QueuedAction.fromJson((item as Map).cast<String, dynamic>()));
          } catch (_) {
            // Skip a single corrupt/forward-incompatible entry instead of losing
            // the whole queue (e.g. a QueuedKind added by a newer app version).
          }
        }
      } catch (_) {
        // Unparseable blob -> start clean rather than crash on launch.
      }
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

  /// Drain the queue oldest-first to preserve per-shipment ordering.
  ///
  /// Failure handling:
  ///  - 401  -> token is dead; stop now and resume after the rider re-logs in.
  ///  - 4xx  -> the action is bad or a duplicate replay the server already applied
  ///            (the procs are idempotent and reject replays), so drop it.
  ///  - 5xx  -> count an attempt; keep & retry, but after [_maxAttempts] park the
  ///            poison action so it can't block every later action forever.
  ///  - network error -> keep & retry on the next connectivity change (no penalty,
  ///            since being offline is expected and transient).
  Future<void> flush() async {
    if (_flushing) {
      _flushRequested = true; // coalesce: re-run once the current pass finishes
      return;
    }
    _flushing = true;
    try {
      do {
        _flushRequested = false;
        if (!await _isOnline()) return;

        while (_pending.isNotEmpty) {
          final action = _pending.first;
          try {
            await api.post(action.path, action.body);
            await _removeHead();
          } on ApiException catch (e) {
            if (e.statusCode == 401) {
              return; // session ended; api_client has triggered logout
            }
            if (e.statusCode >= 400 && e.statusCode < 500) {
              await _removeHead(); // bad/duplicate -> drop and continue
            } else {
              // 5xx: cap retries so one poison action can't stall the rest.
              action.attempts++;
              if (action.attempts >= _maxAttempts) {
                await _removeHead(); // park/drop poison action
              } else {
                await _persist(); // persist the bumped attempt count
                break; // retry the whole queue later
              }
            }
          } catch (_) {
            break; // network error -> retry later, keep ordering
          }
        }
      } while (_flushRequested);
    } finally {
      _flushing = false;
    }
  }

  Future<void> _removeHead() async {
    _pending.removeAt(0);
    await _persist();
    notifyListeners();
  }
}
