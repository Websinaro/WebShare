import '../../models/transfer_file.dart';
import '../../models/transfer_session.dart';

/// Snapshot of an in-progress transfer, emitted repeatedly while it runs.
class TransferProgress {
  final TransferPhase phase;
  final String? currentFileName;
  final int filesCompleted;
  final int filesTotal;
  final int bytesTransferred;
  final int bytesTotal;
  final double speedBytesPerSecond;
  final Duration eta;
  final String? errorMessage;

  const TransferProgress({
    required this.phase,
    this.currentFileName,
    required this.filesCompleted,
    required this.filesTotal,
    required this.bytesTransferred,
    required this.bytesTotal,
    required this.speedBytesPerSecond,
    required this.eta,
    this.errorMessage,
  });

  double get fraction => bytesTotal == 0 ? 0 : bytesTransferred / bytesTotal;
}

/// The seam between Flutter and the native Kotlin transfer engine.
///
/// Flutter NEVER moves file bytes itself — this interface only carries
/// metadata, progress, and control signals across a MethodChannel/EventChannel
/// pair in the real implementation. Every method here maps 1:1 to a message
/// that will cross that channel.
abstract class TransferEngine {
  /// Sender side: start hosting a session for [files]; returns the session
  /// info to encode into the QR code once the native server is listening.
  Future<TransferSession> startHosting(List<TransferFile> files);

  /// Receiver side: connect to a session decoded from a scanned QR code.
  Future<List<TransferFile>> connectToSession(TransferSession session);

  /// Receiver side: begin pulling the given file ids from the connected session.
  Stream<TransferProgress> receiveFiles(List<String> fileIds);

  /// Sender side: stream of progress once the receiver has started pulling files.
  Stream<TransferProgress> sendProgress();

  Future<void> pause();
  Future<void> resume();
  Future<void> cancel();
}
