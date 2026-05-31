import 'api_client.dart';
import 'auth_store.dart';
import 'rider_api.dart';
import 'sync_queue.dart';

/// Tiny manual service locator. Keeps wiring simple without a DI package.
class Services {
  static late AuthStore auth;
  static late ApiClient api;
  static late SyncQueue queue;
  static late RiderApi rider;

  static Future<void> init() async {
    auth = AuthStore();
    await auth.load();
    api = ApiClient(auth);
    queue = SyncQueue(api);
    await queue.load();
    rider = RiderApi(api, auth, queue);
  }
}
