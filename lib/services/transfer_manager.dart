import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/shared_file.dart';

/// Drives a multi-file download queue from a host's [FileServer] and keeps
/// running via a foreground service notification while the app is
/// backgrounded, so a large batch (videos, zips, apks, anything) doesn't get
/// killed the moment the user switches apps.
class TransferManager {
  TransferManager._();
  static final TransferManager instance = TransferManager._();

  final _controller = StreamController<List<TransferItem>>.broadcast();
  Stream<List<TransferItem>> get updates => _controller.stream;

  final List<TransferItem> _queue = [];
  bool _cancelRequested = false;
  bool _running = false;

  List<TransferItem> get queue => List.unmodifiable(_queue);

  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'webshare_transfer',
        channelName: 'WebShare transfers',
        channelDescription: 'Shows progress while files are being sent or received.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  /// Fetches the file list from the sender's server (the URL that was
  /// scanned from the QR code, e.g. http://192.168.1.5:54321).
  Future<List<SharedFile>> fetchRemoteFiles(String baseUrl) async {
    final res = await http.get(Uri.parse('$baseUrl/files'));
    if (res.statusCode != 200) {
      throw Exception('Could not reach sender (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => SharedFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> startDownloads(String baseUrl, List<SharedFile> files) async {
    if (_running) return;
    _running = true;
    _cancelRequested = false;
    _queue
      ..clear()
      ..addAll(files.map((f) => TransferItem(file: f)));
    _emit();

    await FlutterForegroundTask.startService(
      notificationTitle: 'WebShare',
      notificationText: 'Preparing to receive ${files.length} file(s)…',
    );

    final dir = await _downloadsDir();

    for (final item in _queue) {
      if (_cancelRequested) {
        item.state = TransferState.canceled;
        _emit();
        continue;
      }
      await _downloadOne(baseUrl, item, dir);
    }

    await FlutterForegroundTask.updateService(
      notificationTitle: 'WebShare',
      notificationText: 'Transfer complete',
    );
    await Future.delayed(const Duration(seconds: 2));
    await FlutterForegroundTask.stopService();
    _running = false;
  }

  Future<void> _downloadOne(
      String baseUrl, TransferItem item, Directory dir) async {
    item.state = TransferState.inProgress;
    _emit();

    final savePath = p.join(dir.path, item.file.name);
    final file = File(savePath);
    final sink = file.openWrite();

    try {
      final request =
          http.Request('GET', Uri.parse('$baseUrl/download/${item.file.id}'));
      final response = await http.Client().send(request);

      await for (final chunk in response.stream) {
        if (_cancelRequested) {
          item.state = TransferState.canceled;
          break;
        }
        sink.add(chunk);
        item.bytesTransferred += chunk.length;
        _emit();
      }

      await sink.flush();
      await sink.close();

      if (item.state != TransferState.canceled) {
        item.state = TransferState.done;
      }
    } catch (_) {
      item.state = TransferState.failed;
      await sink.close();
    }

    await FlutterForegroundTask.updateService(
      notificationTitle: 'WebShare — receiving',
      notificationText:
          '${_queue.where((i) => i.state == TransferState.done).length}/${_queue.length} files done',
    );
    _emit();
  }

  Future<Directory> _downloadsDir() async {
    Directory base;
    if (Platform.isAndroid) {
      base = Directory('/storage/emulated/0/Download/WebShare');
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  void cancelAll() {
    _cancelRequested = true;
  }

  void _emit() => _controller.add(List.unmodifiable(_queue));
}
