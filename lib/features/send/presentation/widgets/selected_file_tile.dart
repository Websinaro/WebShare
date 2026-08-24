import 'package:flutter/material.dart';
import '../../../../models/transfer_file.dart';

IconData iconForExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'heic':
      return Icons.image_outlined;
    case 'mp4':
    case 'mov':
    case 'mkv':
      return Icons.movie_outlined;
    case 'mp3':
    case 'wav':
    case 'm4a':
      return Icons.audiotrack_outlined;
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip_outlined;
    case 'apk':
      return Icons.android_outlined;
    case 'doc':
    case 'docx':
    case 'txt':
      return Icons.description_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

String formatBytes(int bytes) {
  if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

class SelectedFileTile extends StatelessWidget {
  final TransferFile file;
  final VoidCallback onRemove;

  const SelectedFileTile({super.key, required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(iconForExtension(file.extension), color: scheme.onPrimaryContainer, size: 20),
        ),
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(formatBytes(file.sizeBytes)),
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          onPressed: onRemove,
          tooltip: 'Remove',
        ),
      ),
    );
  }
}
