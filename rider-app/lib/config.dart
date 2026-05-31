/// App configuration. Values are provided at build time via --dart-define so no
/// secrets are hardcoded in source. Example:
///   flutter run \
///     --dart-define=API_BASE_URL=http://10.0.2.2:5080 \
///     --dart-define=ONESIGNAL_APP_ID=xxxx \
///     --dart-define=MAPS_API_KEY=yyyy
class AppConfig {
  // 10.0.2.2 is the Android emulator's alias for the host machine's localhost.
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5080');

  static const String oneSignalAppId =
      String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '');

  // Maps/routing key (Google Directions or similar). Keep configurable.
  static const String mapsApiKey =
      String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
}
