import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/gradient_progress_ring.dart';
import '../../../models/transfer_session.dart';
import '../../../services/transfer/transfer_engine.dart';
import '../../send/presentation/widgets/selected_file_tile.dart';

enum TransferRole { sender, receiver }

/// Passed via go_router `extra` to tell the shared Transfer screen which
/// side of the exchange this device is on, and (for receivers) which
/// file ids were selected on the Incoming Files screen.
class TransferRoleArgs {
  final TransferRole role;
  final List<String> fileIds;

  TransferRoleArgs.sender()
      : role = TransferRole.sender,
        fileIds = const [];

  TransferRoleArgs.receiver(this.fileIds) : role = TransferRole.receiver;
}

class TransferScreen extends ConsumerStatefulWidget {
  final TransferRoleArgs args;
  const TransferScreen({super.key, required this.args});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  TransferProgress? _progress;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(transferEngineProvider);
    final stream = widget.args.role == TransferRole.sender
        ? engine.sendProgress()
        : engine.receiveFiles(widget.args.fileIds);

    stream.listen((p) {
      if (!mounted) return;
      setState(() => _progress = p);
      if (p.phase == TransferPhase.completed) {
        context.pushReplacement('/transfer/completed', extra: p);
      } else if (p.phase == TransferPhase.cancelled) {
        context.pop();
      }
    });
  }

  String _formatSpeed(double bytesPerSecond) {
    final mbps = bytesPerSecond / (1024 * 1024);
    return '${mbps.toStringAsFixed(1)} MB/s';
  }

  String _formatEta(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s left';
    return '${d.inSeconds}s left';
  }

  String _formatBytesPair(int done, int total) => '${formatBytes(done)} / ${formatBytes(total)}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = _progress;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.args.role == TransferRole.sender ? 'Sending' : 'Receiving'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: p == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: p.fraction),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              builder: (context, value, _) => GradientProgressRing(
                                progress: value,
                                strokeWidth: 10,
                                gradient: widget.args.role == TransferRole.sender
                                    ? AppGradients.primary
                                    : AppGradients.receive,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(p.fraction * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                Text('${p.filesCompleted}/${p.filesTotal} files',
                                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          p.currentFileName ?? '',
                          key: ValueKey(p.currentFileName),
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Stat(icon: Icons.speed_rounded, label: _formatSpeed(p.speedBytesPerSecond)),
                          _Stat(icon: Icons.schedule_rounded, label: _formatEta(p.eta)),
                          _Stat(icon: Icons.sync_alt_rounded, label: _formatBytesPair(p.bytesTransferred, p.bytesTotal)),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final engine = ref.read(transferEngineProvider);
                                if (_paused) {
                                  await engine.resume();
                                } else {
                                  await engine.pause();
                                }
                                setState(() => _paused = !_paused);
                              },
                              icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                              label: Text(_paused ? 'Resume' : 'Pause'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                              onPressed: () => ref.read(transferEngineProvider).cancel(),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Cancel'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
