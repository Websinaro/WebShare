enum TransferDirection { sent, received }
enum TransferStatus { completed, failed, cancelled }

class TransferRecord {
  final String id;
  final String primaryFileName;
  final int fileCount;
  final int totalBytes;
  final DateTime timestamp;
  final TransferDirection direction;
  final TransferStatus status;
  final Duration duration;

  const TransferRecord({
    required this.id,
    required this.primaryFileName,
    required this.fileCount,
    required this.totalBytes,
    required this.timestamp,
    required this.direction,
    required this.status,
    required this.duration,
  });
}
