/// The information encoded into (and decoded from) the QR code that
/// links a sender and receiver on the same local network.
///
/// [ssid]/[passphrase] are the Wi-Fi Direct group's credentials — the
/// receiver joins that network directly rather than needing a separate
/// peer-discovery step. [host]/[port]/[token] identify the sender's
/// transfer server once that connection is up.
class TransferSession {
  final String sessionId;
  final String host;
  final int port;
  final String token;
  final String deviceName;
  final String? ssid;
  final String? passphrase;

  const TransferSession({
    required this.sessionId,
    required this.host,
    required this.port,
    required this.token,
    required this.deviceName,
    this.ssid,
    this.passphrase,
  });
}

enum TransferPhase {
  idle,
  preparing,
  waitingForPeer,
  connected,
  transferring,
  paused,
  completed,
  failed,
  cancelled,
}
