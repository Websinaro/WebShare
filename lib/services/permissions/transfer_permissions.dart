import 'package:permission_handler/permission_handler.dart';

/// Requests whatever this Android version actually needs for Wi-Fi Direct
/// + local file access. permission_handler resolves each Permission to a
/// no-op success on API levels where it isn't a runtime permission, so this
/// is safe to call unconditionally across API 23-36.
class TransferPermissions {
  static Future<bool> ensureForTransfer() async {
    final statuses = await [
      Permission.locationWhenInUse, // needed for Wi-Fi scan/connect on API < 33
      Permission.nearbyWifiDevices, // needed on API 33+
      Permission.camera, // QR scanning
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.notification, // foreground transfer notice on API 33+
    ].request();

    // A permission this OS version doesn't use resolves as granted by the
    // plugin already, so this just checks the ones that actually applied.
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }
}
