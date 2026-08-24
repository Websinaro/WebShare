import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/flowing_gradient_surface.dart';
import '../../../models/transfer_file.dart';
import '../application/send_controller.dart';
import 'widgets/selected_file_tile.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  bool _picking = false;

  Future<void> _pickFiles() async {
    setState(() => _picking = true);
    try {
      // withReadStream covers pickers that don't hand back a real filesystem
      // path (cloud-backed sources like Drive/OneDrive) — those files get
      // streamed into local app storage below so the native transfer server
      // always has a real path to open.
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withReadStream: true,
      );
      if (result == null) return; // user cancelled — not an error

      final rand = Random();
      final files = <TransferFile>[];
      var skipped = 0;

      for (final f in result.files) {
        final ext = (f.extension ?? '').toLowerCase();
        var path = f.path;

        if (path == null && f.readStream != null) {
          final tempDir = await getTemporaryDirectory();
          final dest = File('${tempDir.path}/webshare_pick_${rand.nextInt(1 << 32)}_${f.name}');
          final sink = dest.openWrite();
          await f.readStream!.forEach(sink.add);
          await sink.close();
          path = dest.path;
        }

        if (path == null) {
          skipped++;
          continue;
        }

        files.add(TransferFile(
          id: 'local-${rand.nextInt(1 << 32)}',
          name: f.name,
          extension: ext,
          sizeBytes: f.size,
          localPath: path,
        ));
      }

      if (files.isNotEmpty) {
        ref.read(sendControllerProvider.notifier).addFiles(files);
      }
      if (skipped > 0 && mounted) {
        _showMessage('Couldn\'t read $skipped file${skipped == 1 ? '' : 's'} — try picking again.');
      }
    } catch (e) {
      if (mounted) _showMessage('Couldn\'t open file picker: $e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(sendControllerProvider);
    final totalBytes = ref.read(sendControllerProvider.notifier).totalBytes;

    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: files.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: FadeSlideIn(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const EmptyState(
                                icon: Icons.file_upload_outlined,
                                title: 'No files selected',
                                message: 'Choose any files, photos, videos, or\napps to send to a nearby device.',
                              ),
                              const SizedBox(height: 20),
                              _picking
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(),
                                    )
                                  : FilledButton.icon(
                                      onPressed: _pickFiles,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Choose files'),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      children: [
                        for (var i = 0; i < files.length; i++)
                          FadeSlideIn(
                            delay: Duration(milliseconds: 40 * i),
                            child: SelectedFileTile(
                              file: files[i],
                              onRemove: () =>
                                  ref.read(sendControllerProvider.notifier).remove(files[i].id),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _picking ? null : _pickFiles,
                          icon: _picking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add),
                          label: Text(_picking ? 'Adding…' : 'Add more files'),
                        ),
                      ],
                    ),
            ),
            if (files.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: FlowingGradientSurface(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(18),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/send/preparing'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          child: Row(
                            children: [
                              const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Send ${files.length} file${files.length == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      formatBytes(totalBytes),
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
