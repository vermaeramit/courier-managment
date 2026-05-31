import '../models/models.dart';
import 'api_client.dart';
import 'auth_store.dart';
import 'sync_queue.dart';

/// Higher-level rider operations. Reads go straight to the API; writes go through
/// the offline queue so they survive loss of connectivity.
class RiderApi {
  final ApiClient api;
  final AuthStore auth;
  final SyncQueue queue;

  RiderApi(this.api, this.auth, this.queue);

  Future<AuthUser> login(String email, String password) async {
    final res = await api.post('/api/auth/login', {'email': email, 'password': password});
    final user = AuthUser.fromJson(res['user'] as Map<String, dynamic>);
    await auth.save(res['token'] as String, user);
    return user;
  }

  Future<List<RiderStop>> dailyStops() async {
    final res = await api.get('/api/rider/stops') as List;
    return res.map((e) => RiderStop.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Open a shipment by scanned barcode/tracking id (uses the public tracking read).
  Future<Map<String, dynamic>?> lookupByTracking(String trackingId) async {
    final res = await api.get('/api/track/$trackingId');
    return res as Map<String, dynamic>?;
  }

  // ---- Writes: queued for offline resilience ----

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> updateStatus(int shipmentId, String status,
      {double? lat, double? lng, String? remarks}) async {
    await queue.enqueue(QueuedAction(
      id: _newId(),
      kind: QueuedKind.statusUpdate,
      path: '/api/shipments/$shipmentId/status',
      body: {
        'shipmentId': shipmentId,
        'status': status,
        'latitude': lat,
        'longitude': lng,
        'remarks': remarks,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> submitPod(int shipmentId,
      {required String type,
      String? photoUrl,
      String? otp,
      double? lat,
      double? lng,
      double? codCollected,
      String? remarks}) async {
    await queue.enqueue(QueuedAction(
      id: _newId(),
      kind: QueuedKind.pod,
      path: '/api/shipments/$shipmentId/pod',
      body: {
        'shipmentId': shipmentId,
        'type': type,
        'photoUrl': photoUrl,
        'otp': otp,
        'riderId': auth.user?.id,
        'latitude': lat,
        'longitude': lng,
        'codCollected': codCollected,
        'remarks': remarks,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> recordCod(int shipmentId, double amount) async {
    await queue.enqueue(QueuedAction(
      id: _newId(),
      kind: QueuedKind.cod,
      path: '/api/cod/record',
      body: {
        'shipmentId': shipmentId,
        'riderId': auth.user?.id,
        'amountCollected': amount,
      },
      createdAt: DateTime.now(),
    ));
  }
}
