import '../../models/transfer_record.dart';

/// Abstraction over transfer history storage. The real implementation will
/// read from a local DB fed by Kotlin transfer-completion events — UI code
/// must never depend on anything but this interface.
abstract class TransferHistoryService {
  Future<List<TransferRecord>> getRecent({int limit = 5});
  Future<List<TransferRecord>> getAll();
  Future<void> add(TransferRecord record);
}
