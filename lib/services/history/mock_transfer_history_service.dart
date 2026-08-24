import '../../models/transfer_record.dart';
import 'transfer_history_service.dart';

class MockTransferHistoryService implements TransferHistoryService {
  final List<TransferRecord> _records = [
    TransferRecord(
      id: 'h1',
      primaryFileName: 'Summer_Trip.mp4',
      fileCount: 1,
      totalBytes: 482 * 1024 * 1024,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      direction: TransferDirection.sent,
      status: TransferStatus.completed,
      duration: const Duration(seconds: 42),
    ),
    TransferRecord(
      id: 'h2',
      primaryFileName: 'Resume.pdf',
      fileCount: 3,
      totalBytes: 6 * 1024 * 1024,
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      direction: TransferDirection.received,
      status: TransferStatus.completed,
      duration: const Duration(seconds: 5),
    ),
    TransferRecord(
      id: 'h3',
      primaryFileName: 'Project_Archive.zip',
      fileCount: 1,
      totalBytes: 1200 * 1024 * 1024,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      direction: TransferDirection.sent,
      status: TransferStatus.failed,
      duration: const Duration(seconds: 12),
    ),
  ];

  @override
  Future<List<TransferRecord>> getRecent({int limit = 5}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _records.take(limit).toList();
  }

  @override
  Future<List<TransferRecord>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_records);
  }

  @override
  Future<void> add(TransferRecord record) async {
    _records.insert(0, record);
  }
}
