import 'dart:async';
import 'dart:math';

import '../../models/transfer_file.dart';
import '../../models/transfer_session.dart';
import 'transfer_engine.dart';

/// Simulates the native engine's behavior so every screen is fully
/// interactive during UI development. Produces the same event shape
/// the real Kotlin EventChannel will produce — swapping this out for
/// the real implementation requires no changes above this file.
class MockTransferEngine implements TransferEngine {
  final _rand = Random();
  bool _cancelled = false;
  bool _paused = false;

  @override
  Future<TransferSession> startHosting(List<TransferFile> files) async {
    await Future.delayed(const Duration(milliseconds: 900));
    return TransferSession(
      sessionId: 'sess-${_rand.nextInt(999999)}',
      host: '192.168.49.1',
      port: 8988,
      token: List.generate(8, (_) => _rand.nextInt(10)).join(),
      deviceName: 'This device',
    );
  }

  @override
  Future<List<TransferFile>> connectToSession(TransferSession session) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return [
      const TransferFile(id: 'f1', name: 'Vacation_Photos.zip', extension: 'zip', sizeBytes: 214 * 1024 * 1024),
      const TransferFile(id: 'f2', name: 'Invoice_August.pdf', extension: 'pdf', sizeBytes: 2 * 1024 * 1024),
      const TransferFile(id: 'f3', name: 'Demo_App.apk', extension: 'apk', sizeBytes: 34 * 1024 * 1024),
    ];
  }

  @override
  Stream<TransferProgress> receiveFiles(List<String> fileIds) => _simulate(fileIds.length);

  @override
  Stream<TransferProgress> sendProgress() => _simulate(2);

  Stream<TransferProgress> _simulate(int fileCount) {
    _cancelled = false;
    _paused = false;
    final controller = StreamController<TransferProgress>();

    const totalBytes = 250 * 1024 * 1024;
    var transferred = 0;
    var completedFiles = 0;
    final names = ['Vacation_Photos.zip', 'Invoice_August.pdf', 'Demo_App.apk'];

    Timer.periodic(const Duration(milliseconds: 220), (timer) {
      if (_cancelled) {
        controller.add(TransferProgress(
          phase: TransferPhase.cancelled,
          filesCompleted: completedFiles,
          filesTotal: fileCount,
          bytesTransferred: transferred,
          bytesTotal: totalBytes,
          speedBytesPerSecond: 0,
          eta: Duration.zero,
        ));
        controller.close();
        timer.cancel();
        return;
      }
      if (_paused) return;

      final chunk = 3 + _rand.nextInt(6) * 1024 * 1024 ~/ 100;
      transferred = min(transferred + chunk, totalBytes);
      final speed = 8 + _rand.nextDouble() * 6; // MB/s-ish, scaled below
      final speedBps = speed * 1024 * 1024;
      final remaining = totalBytes - transferred;
      final eta = Duration(seconds: (remaining / speedBps).round());

      if (transferred >= totalBytes) {
        controller.add(TransferProgress(
          phase: TransferPhase.completed,
          currentFileName: names[fileCount - 1 < names.length ? fileCount - 1 : 0],
          filesCompleted: fileCount,
          filesTotal: fileCount,
          bytesTransferred: totalBytes,
          bytesTotal: totalBytes,
          speedBytesPerSecond: speedBps,
          eta: Duration.zero,
        ));
        controller.close();
        timer.cancel();
        return;
      }

      final progressFraction = transferred / totalBytes;
      completedFiles = min((progressFraction * fileCount).floor(), fileCount - 1);

      controller.add(TransferProgress(
        phase: TransferPhase.transferring,
        currentFileName: names[completedFiles % names.length],
        filesCompleted: completedFiles,
        filesTotal: fileCount,
        bytesTransferred: transferred,
        bytesTotal: totalBytes,
        speedBytesPerSecond: speedBps,
        eta: eta,
      ));
    });

    return controller.stream;
  }

  @override
  Future<void> pause() async => _paused = true;

  @override
  Future<void> resume() async => _paused = false;

  @override
  Future<void> cancel() async => _cancelled = true;
}
