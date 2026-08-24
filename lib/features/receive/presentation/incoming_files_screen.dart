import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../features/transfer/presentation/transfer_screen.dart';
import '../../../models/transfer_file.dart';
import '../../send/presentation/widgets/selected_file_tile.dart';

class IncomingFilesScreen extends ConsumerStatefulWidget {
  final List<TransferFile> files;
  const IncomingFilesScreen({super.key, required this.files});

  @override
  ConsumerState<IncomingFilesScreen> createState() => _IncomingFilesScreenState();
}

class _IncomingFilesScreenState extends ConsumerState<IncomingFilesScreen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.files.map((f) => f.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedFiles = widget.files.where((f) => _selected.contains(f.id));
    final totalBytes = selectedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming files'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _selected = _selected.length == widget.files.length
                  ? {}
                  : widget.files.map((f) => f.id).toSet();
            }),
            child: Text(_selected.length == widget.files.length ? 'Deselect all' : 'Select all'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                itemCount: widget.files.length,
                itemBuilder: (context, i) {
                  final file = widget.files[i];
                  final isSelected = _selected.contains(file.id);
                  return FadeSlideIn(
                    delay: Duration(milliseconds: 40 * i),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isSelected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(file.id);
                          } else {
                            _selected.remove(file.id);
                          }
                        }),
                        secondary: Icon(iconForExtension(file.extension)),
                        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatBytes(file.sizeBytes)),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () {
                          ref.read(transferEngineProvider); // ensures engine is ready
                          context.pushReplacement(
                            '/transfer',
                            extra: TransferRoleArgs.receiver(_selected.toList()),
                          );
                        },
                  child: Text(
                    _selected.length == widget.files.length
                        ? 'Receive all (${formatBytes(totalBytes)})'
                        : 'Receive ${_selected.length} selected (${formatBytes(totalBytes)})',
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
