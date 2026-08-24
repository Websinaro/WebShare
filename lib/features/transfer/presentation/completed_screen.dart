import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../services/transfer/transfer_engine.dart';
import '../../send/presentation/widgets/selected_file_tile.dart';

class CompletedScreen extends StatefulWidget {
  final TransferProgress result;
  const CompletedScreen({super.key, required this.result});

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.result;
    final avgSpeed = r.bytesTotal > 0 ? r.speedBytesPerSecond : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(gradient: AppGradients.success, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 56, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              Text('Transfer complete', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '${r.filesTotal} file${r.filesTotal == 1 ? '' : 's'} · ${formatBytes(r.bytesTotal)}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SummaryStat(label: 'Duration', value: '~${(r.bytesTotal / (avgSpeed == 0 ? 1 : avgSpeed)).round()}s'),
                      _SummaryStat(label: 'Avg. speed', value: '${(avgSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s'),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Done'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {}, // Real build: opens/shares received files
                child: const Text('Open files'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
