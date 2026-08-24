import 'package:flutter/material.dart';
import '../../../../models/transfer_record.dart';

class TransferListTile extends StatelessWidget {
  final TransferRecord record;
  const TransferListTile({super.key, required this.record});

  String _formatSize(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final isSent = record.direction == TransferDirection.sent;
    final scheme = Theme.of(context).colorScheme;
    final isFailed = record.status == TransferStatus.failed;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(
          isSent ? Icons.upload_rounded : Icons.download_rounded,
          color: scheme.onSecondaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        record.fileCount > 1
            ? '${record.primaryFileName} +${record.fileCount - 1} more'
            : record.primaryFileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(_formatSize(record.totalBytes)),
      trailing: Icon(
        isFailed ? Icons.error_outline : Icons.check_circle,
        color: isFailed ? scheme.error : Colors.green,
        size: 18,
      ),
    );
  }
}
