/// Represents a single file offered by the sender (any extension/size:
/// video, .ts, .zip, .py, .cpp, .apk, images, docs, folders zipped, etc).
class SharedFile {
  final String id;
  final String name;
  final int size;
  final String path;
  final String extension;

  SharedFile({
    required this.id,
    required this.name,
    required this.size,
    required this.path,
  }) : extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'extension': extension,
      };

  factory SharedFile.fromJson(Map<String, dynamic> json, {String path = ''}) {
    return SharedFile(
      id: json['id'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      path: path,
    );
  }
}

/// Status of one item in a multi-file transfer queue (send or receive side).
enum TransferState { queued, inProgress, done, failed, canceled }

class TransferItem {
  final SharedFile file;
  TransferState state;
  int bytesTransferred;

  TransferItem({
    required this.file,
    this.state = TransferState.queued,
    this.bytesTransferred = 0,
  });

  double get progress => file.size == 0 ? 0 : bytesTransferred / file.size;
}
