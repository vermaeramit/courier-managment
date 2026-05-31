# Rider app — platform setup

This folder ships only `lib/` + `pubspec.yaml` (the cross-platform code). Generate
the native Android/iOS projects once, then add the permissions below.

```bash
cd rider-app
flutter create .          # generates android/, ios/, etc. without touching lib/
flutter pub get
```

## Required runtime permissions

The app uses the camera (barcode scan + POD photo) and location (event geo-tagging).

### Android — `android/app/src/main/AndroidManifest.xml`
Add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

`mobile_scanner` needs `minSdkVersion 21`; set it in `android/app/build.gradle`.

### iOS — `ios/Runner/Info.plist`
Add:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan package barcodes and capture proof of delivery.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Tag delivery events with your location.</string>
```

## Run

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5080 \
  --dart-define=ONESIGNAL_APP_ID=<your-onesignal-app-id> \
  --dart-define=MAPS_API_KEY=<your-maps-key>
```

`10.0.2.2` is the Android emulator's alias for the host's `localhost`. On a
physical device, use your machine's LAN IP.
