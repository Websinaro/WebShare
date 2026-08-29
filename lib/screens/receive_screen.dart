import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/shared_file.dart';
import '../services/transfer_manager.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

enum _Step { scan, chooseFiles, transferring }

class _ReceiveScreenState extends State<ReceiveScreen> {
  _Step _step = _Step.scan;
  String? _baseUrl;
  List<SharedFile> _remoteFiles = [];
  final Set<String> _selected = {};
  bool _loadingList = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.notification.request();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_loadingList) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || !code.startsWith('http')) return;

    setState(() {
      _loadingList = true;
      _error = null;
    });

    try {
      final files = await TransferManager.instance.fetchRemoteFiles(code);
      setState(() {
        _baseUrl = code;
        _remoteFiles = files;
        _selected.addAll(files.map((f) => f.id)); // default: select all
        _step = _Step.chooseFiles;
        _loadingList = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not connect. Make sure both devices are on the same '
            'Wi-Fi network.';
        _loadingList = false;
      });
    }
  }

  void _startTransfer() {
    final files = _remoteFiles.where((f) => _selected.contains(f.id)).toList();
    if (files.isEmpty || _baseUrl == null) return;
    setState(() => _step = _Step.transferring);
    TransferManager.instance.startDownloads(_baseUrl!, files);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: switch (_step) {
        _Step.scan => _buildScanner(),
        _Step.chooseFiles => _buildFileChooser(),
        _Step.transferring => _buildProgress(),
      },
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(onDetect: _onDetect),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ??
                      'Point the camera at the QR code shown on the sending device',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: _error != null ? Colors.redAccent : Colors.white),
                ),
                if (_loadingList) ...[
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileChooser() {
    final totalSelected = _remoteFiles
        .where((f) => _selected.contains(f.id))
        .fold<int>(0, (sum, f) => sum + f.size);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _remoteFiles.length,
            itemBuilder: (context, i) {
              final f = _remoteFiles[i];
              return CheckboxListTile(
                value: _selected.contains(f.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(f.id);
                  } else {
                    _selected.remove(f.id);
                  }
                }),
                title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${f.extension.toUpperCase()} · ${filesize(f.size)}'),
                secondary: const Icon(Icons.insert_drive_file),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _selected.isEmpty ? null : _startTransfer,
              icon: const Icon(Icons.download_rounded),
              label: Text('Download ${_selected.length} file(s) · '
                  '${filesize(totalSelected)}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return StreamBuilder<List<TransferItem>>(
      stream: TransferManager.instance.updates,
      initialData: TransferManager.instance.queue,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final done = items.where((i) => i.state == TransferState.done).length;
        final allFinished = items.isNotEmpty &&
            items.every((i) => i.state == TransferState.done ||
                i.state == TransferState.failed ||
                i.state == TransferState.canceled);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$done / ${items.length} files complete',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  return ListTile(
                    leading: _stateIcon(item.state),
                    title: Text(item.file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: LinearProgressIndicator(value: item.progress),
                    trailing: Text('${(item.progress * 100).toStringAsFixed(0)}%'),
                  );
                },
              ),
            ),
            if (allFinished)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () => TransferManager.instance.cancelAll(),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel remaining'),
                ),
              ),
          ],
        );
      },
    );
  }

  Icon _stateIcon(TransferState s) => switch (s) {
        TransferState.queued => const Icon(Icons.schedule, color: Colors.grey),
        TransferState.inProgress => const Icon(Icons.downloading, color: Colors.blue),
        TransferState.done => const Icon(Icons.check_circle, color: Colors.green),
        TransferState.failed => const Icon(Icons.error, color: Colors.red),
        TransferState.canceled => const Icon(Icons.block, color: Colors.orange),
      };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
