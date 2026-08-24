import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/flowing_gradient_surface.dart';
import '../../../core/widgets/radar_pulse.dart';
import '../../../features/transfer/presentation/transfer_screen.dart';
import '../../../models/transfer_session.dart';
import '../../../services/qr/qr_session_codec.dart';
import '../application/send_controller.dart';

class PreparingTransferScreen extends ConsumerStatefulWidget {
  const PreparingTransferScreen({super.key});

  @override
  ConsumerState<PreparingTransferScreen> createState() => _PreparingTransferScreenState();
}

class _PreparingTransferScreenState extends ConsumerState<PreparingTransferScreen>
    with SingleTickerProviderStateMixin {
  TransferSession? _session;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _startHosting();
  }

  Future<void> _startHosting() async {
    final files = ref.read(sendControllerProvider);
    final engine = ref.read(transferEngineProvider);

    final TransferSession session;
    try {
      session = await engine.startHosting(files);
    } catch (e) {
      if (mounted) _showError('Could not start hosting: $e');
      return;
    }
    if (!mounted) return;
    setState(() => _session = session);

    // The native server only emits a progress event once a receiver has
    // actually connected and started pulling a file — that's the real
    // "receiver joined" signal, not a fixed delay.
    engine.sendProgress().first.then((_) {
      if (mounted) context.pushReplacement('/transfer', extra: TransferRoleArgs.sender());
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Preparing transfer')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: session == null
                      ? const _StartingUp(key: ValueKey('starting'))
                      : RadarPulse(
                          key: const ValueKey('qr'),
                          color: scheme.primary,
                          maxDiameter: 300,
                          child: FlowingGradientSurface(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(28),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: QrImageView(
                                  data: QrSessionCodec.encode(session),
                                  size: 200,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 28),
                if (session != null) ...[
                  Text('Ask the receiver to scan this code',
                      style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Both devices must be on the same Wi-Fi network',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 24),
                  ScaleTransition(
                    scale: Tween(begin: 0.9, end: 1.1).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                    ),
                    child: Chip(
                      avatar: const Icon(Icons.wifi_tethering, size: 18),
                      label: const Text('Waiting for receiver…'),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartingUp extends StatelessWidget {
  const _StartingUp({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 20),
        Text('Setting up connection…', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
