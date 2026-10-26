# Agrynex Mobile App

A Flutter app for iOS and Android that works with the [Agrynex cloud server](https://github.com/CodeSport18/agrynex-cloud-server).

- **Dashboard:** whether the Pi is online, plus switches for the system, animal detection, person detection, siren and sprinkler. The siren and sprinkler show countdowns while they run. Changes made anywhere, including on the Pi's own web page, show up right away.
- **Live view:** the camera, streamed only while this screen is open.
- **Alerts:** new alerts appear as they happen. Each one has a snapshot, a playable clip and what was detected.
- **Settings:** video features, clip length, siren and sprinkler timing, time between alerts, and how long to keep alerts. Only admins can change them.
- **Account:** change your password and sign out. Admins can also add and remove users and reset passwords.

Push notifications aren't part of this build.

## Running

```bash
flutter pub get
flutter run --dart-define=SERVER_URL=https://<your-service>.onrender.com
```

`SERVER_URL` fills in the server address on the sign-in screen. You can also change it there under **Server**.

For a local server, use `http://localhost:8000` on the iOS Simulator and `http://10.0.2.2:8000` on the Android emulator. Debug builds allow plain `http` to local addresses, and release builds need `https`.

## Building for release

```bash
flutter build ipa --dart-define=SERVER_URL=https://<your-service>.onrender.com
flutter build appbundle --dart-define=SERVER_URL=https://<your-service>.onrender.com
```

Publishing to the App Store needs an Apple Developer account. Publishing to Google Play needs a Play Console account and an Android signing key (see Flutter's [Android release guide](https://docs.flutter.dev/deployment/android)).

## Code layout

| Path | What it does |
|---|---|
| `lib/api/` | API client and data models |
| `lib/state/session.dart` | Sign-in. The token is kept in the phone's secure storage |
| `lib/state/realtime.dart` | Socket.IO link for live status, alerts and video |
| `lib/screens/` | Dashboard, live view, alerts, alert detail, settings, account and users |
