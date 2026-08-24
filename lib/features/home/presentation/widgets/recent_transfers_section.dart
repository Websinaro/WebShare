import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/section_header.dart';
import 'transfer_list_tile.dart';

final recentTransfersProvider = FutureProvider((ref) {
  return ref.watch(transferHistoryServiceProvider).getRecent();
});

class RecentTransfersSection extends ConsumerWidget {
  const RecentTransfersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRecords = ref.watch(recentTransfersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent transfers',
          action: 'See all',
          onAction: () => context.push('/history'),
        ),
        const SizedBox(height: 8),
        asyncRecords.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => const EmptyState(
            icon: Icons.error_outline,
            title: "Couldn't load history",
            message: 'Pull to refresh, or try again shortly.',
          ),
          data: (records) {
            if (records.isEmpty) {
              return const EmptyState(
                icon: Icons.swap_horiz_rounded,
                title: 'No transfers yet',
                message: 'Files you send or receive will show up here.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < records.length; i++)
                  FadeSlideIn(
                    delay: Duration(milliseconds: 60 * i),
                    child: TransferListTile(record: records[i]),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
