# WebShare

A Flutter app for sharing files over local Wi-Fi with no internet
connection required — same idea as Xender/SHAREit: one device shows a QR
code, the other scans it, files transfer directly device-to-device over
the local network.

Renamed from the uploaded `my_chat_app` skeleton:
- App name: **WebShare**
- Package / applicationId: **com.webshare.app**
- Project (pubspec) name: **webshare**

## What it does

- **Send**: pick any number of files of any type/size (video, `.ts`,
  `.zip`, `.py`, `.cpp`, `.apk`, photos, docs — `FileType.any`, multi-select)
  and start a local HTTP server. A QR code encodes `http://<your-ip>:<port>`.
- **Receive**: scan that QR code, see the list of offered files, pick which
  ones to pull, and download them with per-file progress. A foreground
  service notification keeps a multi-file batch downloading if you switch
  apps.

## How it works technically

- `lib/services/file_server.dart` — a `shelf` HTTP server on the sender that
  exposes `GET /files` (JSON manifest) and `GET /download/<id>` (streams the
  file, with HTTP range support so a dropped connection can resume).
- `lib/services/transfer_manager.dart` — the receiver's download queue. Uses
  `flutter_foreground_task` to start an Android foreground service +
  notification while transfers run, and `http` to stream each file to disk.
- QR pairing uses `qr_flutter` (generate) and `mobile_scanner` (scan) — the
  payload is just the sender's local URL, nothing proprietary.
- Both devices must be on the **same Wi-Fi network** (or one device's
  mobile hotspot with the other joined to it). There's no true "connect two
  phones directly with no router" mode (that would need Wi-Fi Direct, which
  is a separate, more involved native integration) — this covers the common
  Xender-style case.

## Before you build

This project was edited outside of Android Studio, so you need to run
these once on your machine:

```bash
flutter pub get
flutter analyze          # sanity-check the rename
flutter run               # or open in Android Studio and hit Run
```

flutter pub get will fetch the new dependencies listed in `pubspec.yaml`
(`file_picker`, `shelf`, `shelf_router`, `http`, `network_info_plus`,
`qr_flutter`, `mobile_scanner`, `permission_handler`, `path_provider`,
`flutter_foreground_task`, `flutter_local_notifications`, `filesize`,
`uuid`). `pubspec.lock` and `.dart_tool/` were removed since they pointed at
the old dependency set — they'll regenerate automatically.

### Android manifest permissions already added
Camera (QR scanning), Wi-Fi/network state, storage/media (Android 12 and
below use legacy storage permissions; 13+ use scoped media permissions),
notifications + foreground service (background transfers).

On first run, grant the camera permission (for scanning) and the
notification permission (Android 13+) when prompted — both are requested
automatically on the Receive screen.

### Known limitations / next steps
- No resumable "pause and later resume across app restarts" — a dropped
  connection retries the whole file, not the whole batch.
- No iOS Info.plist camera-usage string was added yet — add
  `NSCameraUsageDescription` to `ios/Runner/Info.plist` if you build for iOS.
- Sending is one-directional per session (device A serves, device B pulls).
  Two-way "send back" would reuse the same server/queue code on both sides.
