import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/primary_action_button.dart';
import 'widgets/recent_transfers_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebShare'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            FadeSlideIn(
              child: PrimaryActionButton(
                icon: Icons.arrow_upward_rounded,
                label: 'Send',
                subtitle: 'Pick files and share them nearby',
                onTap: () => context.push('/send'),
                gradient: AppGradients.primary,
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: PrimaryActionButton(
                icon: Icons.arrow_downward_rounded,
                label: 'Receive',
                subtitle: 'Scan a code to get files',
                onTap: () => context.push('/receive'),
                gradient: AppGradients.receive,
              ),
            ),
            const SizedBox(height: 32),
            const RecentTransfersSection(),
          ],
        ),
      ),
    );
  }
}

