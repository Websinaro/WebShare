import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/history/mock_transfer_history_service.dart';
import '../../services/history/transfer_history_service.dart';
import '../../services/transfer/native_transfer_engine.dart';
import '../../services/transfer/transfer_engine.dart';

/// History storage isn't built natively yet — still a clean seam for later.
final transferHistoryServiceProvider = Provider<TransferHistoryService>(
  (ref) => MockTransferHistoryService(),
);

/// The real transfer engine — talks to the native Kotlin implementation
/// over MethodChannel/EventChannel. See native_transfer_engine.dart.
final transferEngineProvider = Provider<TransferEngine>(
  (ref) => NativeTransferEngine(),
);
