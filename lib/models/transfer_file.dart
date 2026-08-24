class TransferFile {
  final String id;
  final String name;
  final String extension;
  final int sizeBytes;
  final String? localPath;

  const TransferFile({
    required this.id,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    this.localPath,
  });
}
