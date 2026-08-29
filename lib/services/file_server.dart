import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/shared_file.dart';

/// Runs on the "Send" device. Serves the picked files over plain HTTP on the
/// local Wi-Fi network so any device that scans the pairing QR code (or opens
/// the printed URL) can list and download them — same trick Xender/SHAREit
/// use instead of relying on a store app being installed on both ends.
class FileServer {
  HttpServer? _server;
  final Map<String, SharedFile> _files = {};

  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// Registers the files chosen in the Send screen (any extension, any size).
  void setFiles(List<SharedFile> files) {
    _files
      ..clear()
      ..addEntries(files.map((f) => MapEntry(f.id, f)));
  }

  List<SharedFile> get files => _files.values.toList();

  Future<int> start() async {
    if (_server != null) return _server!.port;

    final router = Router();

    router.get('/files', (Request request) {
      final body = jsonEncode(_files.values.map((f) => f.toJson()).toList());
      return Response.ok(body, headers: {'content-type': 'application/json'});
    });

    router.get('/download/<id>', (Request request, String id) {
      final file = _files[id];
      if (file == null) return Response.notFound('unknown file');

      final ioFile = File(file.path);
      if (!ioFile.existsSync()) return Response.notFound('file missing');

      final total = ioFile.lengthSync();
      final rangeHeader = request.headers['range'];

      // Basic HTTP range support so a dropped Wi-Fi connection can resume
      // instead of forcing a full re-download of a multi-GB video file.
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        final start = int.parse(parts[0]);
        final end = parts.length > 1 && parts[1].isNotEmpty
            ? int.parse(parts[1])
            : total - 1;
        final stream = ioFile.openRead(start, end + 1);
        return Response(
          206,
          body: stream,
          headers: {
            'content-type': 'application/octet-stream',
            'content-range': 'bytes $start-$end/$total',
            'accept-ranges': 'bytes',
            'content-length': '${end - start + 1}',
            'content-disposition': 'attachment; filename="${file.name}"',
          },
        );
      }

      return Response.ok(
        ioFile.openRead(),
        headers: {
          'content-type': 'application/octet-stream',
          'accept-ranges': 'bytes',
          'content-length': '$total',
          'content-disposition': 'attachment; filename="${file.name}"',
        },
      );
    });

    final handler =
        const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    // Port 0 = let the OS pick a free port; we encode whatever it chose in
    // the QR code so there's never a "port already in use" failure.
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    return _server!.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
