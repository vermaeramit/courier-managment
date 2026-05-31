/// Plain data models mirroring the API response shapes the rider app consumes.

class AuthUser {
  final int id;
  final String name;
  final String role;
  final int? branchId;
  AuthUser({required this.id, required this.name, required this.role, this.branchId});

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as int,
        name: j['name'] as String,
        role: j['role'] as String,
        branchId: j['branchId'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'branchId': branchId,
      };
}

class RiderStop {
  final int id;
  final String trackingId;
  final String status;
  final String paymentMode;
  final double codAmount;
  final String receiverName;
  final String receiverPhone;
  final String receiverAddress;
  final String receiverPincode;
  final double? amountExpected;

  RiderStop({
    required this.id,
    required this.trackingId,
    required this.status,
    required this.paymentMode,
    required this.codAmount,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverAddress,
    required this.receiverPincode,
    this.amountExpected,
  });

  bool get isCod => paymentMode == 'COD';

  factory RiderStop.fromJson(Map<String, dynamic> j) => RiderStop(
        id: j['id'] as int,
        trackingId: j['trackingId'] as String,
        status: j['status'] as String,
        paymentMode: j['paymentMode'] as String,
        codAmount: (j['codAmount'] as num?)?.toDouble() ?? 0,
        receiverName: j['receiverName'] as String? ?? '',
        receiverPhone: j['receiverPhone'] as String? ?? '',
        receiverAddress: j['receiverAddress'] as String? ?? '',
        receiverPincode: j['receiverPincode'] as String? ?? '',
        amountExpected: (j['amountExpected'] as num?)?.toDouble(),
      );
}

/// A queued action waiting to be synced to the API (offline support).
enum QueuedKind { statusUpdate, pod, cod }

class QueuedAction {
  final String id; // local uuid-ish
  final QueuedKind kind;
  final String path; // API path
  final Map<String, dynamic> body;
  final DateTime createdAt;

  QueuedAction({
    required this.id,
    required this.kind,
    required this.path,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'path': path,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QueuedAction.fromJson(Map<String, dynamic> j) => QueuedAction(
        id: j['id'] as String,
        kind: QueuedKind.values.firstWhere((k) => k.name == j['kind']),
        path: j['path'] as String,
        body: Map<String, dynamic>.from(j['body'] as Map),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
