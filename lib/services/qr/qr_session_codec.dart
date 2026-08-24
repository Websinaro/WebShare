import 'dart:convert';

import '../../models/transfer_session.dart';

/// Encodes/decodes a [TransferSession] to/from the plain string that gets
/// put into (and scanned out of) the QR code. Kept intentionally simple
/// (JSON) so it's easy to version later (e.g. a leading schema byte).
class QrSessionCodec {
  static const _schema = 'webshare-v1';

  static String encode(TransferSession session) {
    return jsonEncode({
      'schema': _schema,
      'sessionId': session.sessionId,
      'host': session.host,
      'port': session.port,
      'token': session.token,
      'deviceName': session.deviceName,
      'ssid': session.ssid,
      'passphrase': session.passphrase,
    });
  }

  static TransferSession? decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['schema'] != _schema) return null;
      return TransferSession(
        sessionId: map['sessionId'] as String,
        host: map['host'] as String,
        port: map['port'] as int,
        token: map['token'] as String,
        deviceName: map['deviceName'] as String,
        ssid: map['ssid'] as String?,
        passphrase: map['passphrase'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
