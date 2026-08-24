import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../models/transfer_file.dart';
import '../application/send_controller.dart';
import 'widgets/selected_file_tile.dart';

class SendScreen extends ConsumerWidget {
  const SendScreen({super.key});

  Future<void> _pickFiles(WidgetRef ref) async {
    // withReadStream covers pickers that don't hand back a real filesystem
    // path (cloud-backed sources like Drive/OneDrive) — those files get
    // streamed into local app storage below so the native transfer server
    // always has a real path to open.
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withReadStream: true,
    );
    if (result == null) return;

    final rand = Random();
    final files = <TransferFile>[];
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

      if (path == null) continue; // no usable source for this file — skip it

      files.add(TransferFile(
        id: 'local-${rand.nextInt(1 << 32)}',
        name: f.name,
        extension: ext,
        sizeBytes: f.size,
        localPath: path,
      ));
    }

    ref.read(sendControllerProvider.notifier).addFiles(files);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                              FilledButton.icon(
                                onPressed: () => _pickFiles(ref),
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
                          onPressed: () => _pickFiles(ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Add more files'),
                        ),
                      ],
                    ),
            ),
            if (files.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
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
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${files.length} file${files.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(formatBytes(totalBytes),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => context.push('/send/preparing'),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
