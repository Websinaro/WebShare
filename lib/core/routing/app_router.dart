import 'package:go_router/go_router.dart';

import '../../features/history/presentation/history_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/receive/presentation/incoming_files_screen.dart';
import '../../features/receive/presentation/receiver_scanner_screen.dart';
import '../../features/send/presentation/preparing_transfer_screen.dart';
import '../../features/send/presentation/send_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transfer/presentation/completed_screen.dart';
import '../../features/transfer/presentation/transfer_screen.dart';
import '../../models/transfer_file.dart';
import '../../services/transfer/transfer_engine.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', name: 'home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/history', builder: (context, state) => const HistoryScreen()),

    // Send flow
    GoRoute(path: '/send', builder: (context, state) => const SendScreen()),
    GoRoute(path: '/send/preparing', builder: (context, state) => const PreparingTransferScreen()),

    // Receive flow
    GoRoute(path: '/receive', builder: (context, state) => const ReceiverScannerScreen()),
    GoRoute(
      path: '/receive/files',
      builder: (context, state) => IncomingFilesScreen(files: state.extra as List<TransferFile>),
    ),

    // Shared transfer + completion
    GoRoute(
      path: '/transfer',
      builder: (context, state) => TransferScreen(args: state.extra as TransferRoleArgs),
    ),
    GoRoute(
      path: '/transfer/completed',
      builder: (context, state) => CompletedScreen(result: state.extra as TransferProgress),
    ),
  ],
);
