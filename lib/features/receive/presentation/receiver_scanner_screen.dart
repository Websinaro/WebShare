import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/providers/service_providers.dart';
import '../../../services/qr/qr_session_codec.dart';

class ReceiverScannerScreen extends ConsumerStatefulWidget {
  const ReceiverScannerScreen({super.key});

  @override
  ConsumerState<ReceiverScannerScreen> createState() => _ReceiverScannerScreenState();
}

class _ReceiverScannerScreenState extends ConsumerState<ReceiverScannerScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;
  bool _connecting = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    final session = QrSessionCodec.decode(raw);
    if (session == null) return; // not a WebShare code — keep scanning

    _handled = true;
    setState(() => _connecting = true);
    await _controller.stop();

    final engine = ref.read(transferEngineProvider);
    final files = await engine.connectToSession(session);

    if (!mounted) return;
    context.pushReplacement('/receive/files', extra: files);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan to receive')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Dim everything outside a centered scan window.
          IgnorePointer(
            child: Container(
              decoration: ShapeDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: _ScannerOverlayShape(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _connecting
                      ? const Chip(
                          key: ValueKey('connecting'),
                          avatar: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          label: Text('Connecting…'),
                        )
                      : Text(
                          key: const ValueKey('hint'),
                          'Point your camera at the sender\'s code',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayShape extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final cutout = Rect.fromCenter(center: rect.center, width: 260, height: 260);
    return Path()
      ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(24)));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final cutout = Rect.fromCenter(center: rect.center, width: 260, height: 260);
    return Path()
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
