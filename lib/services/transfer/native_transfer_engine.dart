import 'package:flutter/services.dart';

import '../../models/transfer_file.dart';
import '../../models/transfer_session.dart';
import '../permissions/transfer_permissions.dart';
import 'transfer_engine.dart';

/// Real implementation, talking to the Kotlin side over a MethodChannel
/// (requests/responses) and an EventChannel (progress stream). This is the
/// concrete class registered in service_providers.dart — the rest of the
/// app only ever depends on the TransferEngine interface.
class NativeTransferEngine implements TransferEngine {
  static const _methodChannel = MethodChannel('com.otha.webshare/transfer');
  static const _eventChannel = EventChannel('com.otha.webshare/progress');

  Stream<TransferProgress>? _sharedProgressStream;

  Stream<TransferProgress> get _progressStream {
    return _sharedProgressStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => _toProgress(event as Map));
  }

  @override
  Future<TransferSession> startHosting(List<TransferFile> files) async {
    final granted = await TransferPermissions.ensureForTransfer();
    if (!granted) {
      throw StateError('Required permissions were not granted.');
    }

    final result = await _methodChannel.invokeMethod<Map>('startHosting', [
      for (final f in files)
        {
          'id': f.id,
          'name': f.name,
          'extension': f.extension,
          'localPath': f.localPath,
        },
    ]);
    final m = result!;
    return TransferSession(
      sessionId: m['sessionId'] as String,
      host: m['host'] as String,
      port: m['port'] as int,
      token: m['token'] as String,
      deviceName: m['deviceName'] as String,
      ssid: m['ssid'] as String?,
      passphrase: m['passphrase'] as String?,
    );
  }

  @override
  Future<List<TransferFile>> connectToSession(TransferSession session) async {
    final granted = await TransferPermissions.ensureForTransfer();
    if (!granted) {
      throw StateError('Required permissions were not granted.');
    }

    final result = await _methodChannel.invokeMethod<List>('connectToSession', {
      'host': session.host,
      'port': session.port,
      'token': session.token,
      'ssid': session.ssid,
      'passphrase': session.passphrase,
    });

    return (result ?? []).map((raw) {
      final m = raw as Map;
      return TransferFile(
        id: m['id'] as String,
        name: m['name'] as String,
        extension: m['extension'] as String,
        sizeBytes: m['sizeBytes'] as int,
      );
    }).toList();
  }

  @override
  Stream<TransferProgress> receiveFiles(List<String> fileIds) {
    _methodChannel.invokeMethod('receiveFiles', fileIds);
    return _progressStream;
  }

  @override
  Stream<TransferProgress> sendProgress() => _progressStream;

  @override
  Future<void> pause() => _methodChannel.invokeMethod('pause');

  @override
  Future<void> resume() => _methodChannel.invokeMethod('resume');

  @override
  Future<void> cancel() => _methodChannel.invokeMethod('cancel');

  TransferProgress _toProgress(Map event) {
    const phaseMap = {
      'transferring': TransferPhase.transferring,
      'completed': TransferPhase.completed,
      'failed': TransferPhase.failed,
      'cancelled': TransferPhase.cancelled,
    };
    return TransferProgress(
      phase: phaseMap[event['phase']] ?? TransferPhase.transferring,
      currentFileName: event['currentFileName'] as String?,
      filesCompleted: event['filesCompleted'] as int,
      filesTotal: event['filesTotal'] as int,
      bytesTransferred: (event['bytesTransferred'] as num).toInt(),
      bytesTotal: (event['bytesTotal'] as num).toInt(),
      speedBytesPerSecond: (event['speedBytesPerSecond'] as num).toDouble(),
      eta: Duration(seconds: (event['etaSeconds'] as num).toInt()),
      errorMessage: event['errorMessage'] as String?,
    );
  }
}
