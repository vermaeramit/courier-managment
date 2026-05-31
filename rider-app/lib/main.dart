import 'package:flutter/material.dart';
import 'services/locator.dart';
import 'services/push_service.dart';
import 'screens/login_screen.dart';
import 'screens/stops_screen.dart';
import 'screens/stop_detail_screen.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Services.init();

  // Push: tapping a notification deep-links to the shipment detail screen.
  await PushService.init(onOpenShipment: (shipmentId) {
    navKey.currentState?.push(MaterialPageRoute(
      builder: (_) => StopDetailScreen.byShipmentId(shipmentId),
    ));
  });

  // Re-register external id if already logged in.
  final user = Services.auth.user;
  if (user != null) {
    await PushService.loginExternalId(user.id);
  }

  runApp(const RiderApp());
}

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Courier Rider',
      navigatorKey: navKey,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: AnimatedBuilder(
        animation: Services.auth,
        builder: (context, _) =>
            Services.auth.isLoggedIn ? const StopsScreen() : const LoginScreen(),
      ),
    );
  }
}
