import 'package:file_picker/file_picker.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/shared_file.dart';
import '../services/file_server.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _server = FileServer();
  final _picked = <SharedFile>[];
  String? _qrPayload;
  bool _starting = false;

  int get _totalBytes => _picked.fold(0, (sum, f) => sum + f.size);

  Future<void> _pickFiles() async {
    // FileType.any + allowMultiple lets the user pick literally anything:
    // .mp4/.mkv videos, .ts segments, .zip, .py, .cpp, .apk, docs, photos...
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withReadStream: false,
    );
    if (result == null) return;

    setState(() {
      for (final f in result.files) {
        if (f.path == null) continue;
        _picked.add(SharedFile(
          id: const Uuid().v4(),
          name: f.name,
          size: f.size,
          path: f.path!,
        ));
      }
    });
  }

  Future<void> _startSharing() async {
    if (_picked.isEmpty) return;
    setState(() => _starting = true);

    _server.setFiles(_picked);
    final port = await _server.start();

    final info = NetworkInfo();
    final ip = await info.getWifiIP();

    if (!mounted) return;

    if (ip == null) {
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Could not detect a Wi-Fi IP. Connect both devices to the same '
            'Wi-Fi network (or one device\'s hotspot) and try again.'),
      ));
      return;
    }

    setState(() {
      _qrPayload = 'http://$ip:$port';
      _starting = false;
    });
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: _qrPayload != null ? _buildQrView() : _buildPickView(),
    );
  }

  Widget _buildPickView() {
    return Column(
      children: [
        Expanded(
          child: _picked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_open, size: 72, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No files selected yet'),
                      const SizedBox(height: 4),
                      const Text(
                        'Any type, any size — videos, zip, py, cpp, apk…',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _picked.length,
                  itemBuilder: (context, i) {
                    final f = _picked[i];
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${f.extension.toUpperCase()} · ${filesize(f.size)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _picked.removeAt(i)),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.add),
                    label: const Text('Add files'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _picked.isEmpty || _starting ? null : _startSharing,
                    icon: _starting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.qr_code),
                    label: Text(_picked.isEmpty
                        ? 'Start sharing'
                        : 'Share ${filesize(_totalBytes)}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan this with the other device\'s WebShare app',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: QrImageView(
                data: _qrPayload!,
                version: QrVersions.auto,
                size: 240,
              ),
            ),
            const SizedBox(height: 16),
            Text(_qrPayload!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('${_picked.length} file(s) · ${filesize(_totalBytes)} ready to send'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await _server.stop();
                setState(() => _qrPayload = null);
              },
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop sharing'),
            ),
          ],
        ),
      ),
    );
  }
}
