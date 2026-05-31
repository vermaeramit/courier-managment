import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../config.dart';

/// OneSignal wiring. On login we set the external user id to Users.Id so the
/// backend can target this rider's device. Notifications carry a `shipmentId`
/// in their data payload for deep-linking.
class PushService {
  /// Called once at startup. Safe no-op if no app id is configured.
  static Future<void> init({required void Function(int shipmentId) onOpenShipment}) async {
    if (AppConfig.oneSignalAppId.isEmpty) {
      debugPrint('OneSignal app id not set; push disabled.');
      return;
    }

    OneSignal.initialize(AppConfig.oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

    // Deep-link when a notification is tapped.
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      final raw = data?['shipmentId'];
      final shipmentId = raw is int ? raw : int.tryParse('$raw');
      if (shipmentId != null) onOpenShipment(shipmentId);
    });
  }

  /// Register the logged-in rider so pushes target this device by Users.Id.
  static Future<void> loginExternalId(int userId) async {
    if (AppConfig.oneSignalAppId.isEmpty) return;
    await OneSignal.login(userId.toString());
  }

  static Future<void> logout() async {
    if (AppConfig.oneSignalAppId.isEmpty) return;
    await OneSignal.logout();
  }
}
