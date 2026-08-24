import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/service_providers.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../models/transfer_record.dart';
import '../../home/presentation/widgets/transfer_list_tile.dart';

final allTransfersProvider = FutureProvider((ref) {
  return ref.watch(transferHistoryServiceProvider).getAll();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allTransfersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer history')),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const Center(
            child: EmptyState(
              icon: Icons.error_outline,
              title: "Couldn't load history",
              message: 'Try again shortly.',
            ),
          ),
          data: (records) {
            if (records.isEmpty) {
              return const Center(
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No transfers yet',
                  message: 'Sent and received files will be listed here.',
                ),
              );
            }
            final grouped = _groupByDate(records);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                  ),
                  for (var i = 0; i < entry.value.length; i++)
                    FadeSlideIn(
                      delay: Duration(milliseconds: 30 * i),
                      child: TransferListTile(record: entry.value[i]),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, List<TransferRecord>> _groupByDate(List<TransferRecord> records) {
    final map = <String, List<TransferRecord>>{};
    final now = DateTime.now();
    for (final r in records) {
      final isToday = r.timestamp.year == now.year && r.timestamp.month == now.month && r.timestamp.day == now.day;
      final isYesterday = now.difference(r.timestamp).inDays == 1 && r.timestamp.day != now.day;
      final key = isToday ? 'Today' : isYesterday ? 'Yesterday' : DateFormat.yMMMd().format(r.timestamp);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }
}
