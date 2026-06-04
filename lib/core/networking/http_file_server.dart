import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:path/path.dart' as p;
import 'package:tether/shared/constants.dart';

/// HTTP file server for chunked file browsing and transfer.
class HttpFileServer {
  HttpServer? _server;
  String? _sharedDirectory;

  bool get isRunning => _server != null;

  /// Start the HTTP file server on the given port.
  Future<void> start({
    String? sharedDirectory,
    int port = TetherConstants.httpFilePort,
  }) async {
    _sharedDirectory = sharedDirectory;

    final router = Router()
      ..get('/api/files', _listFiles)
      ..get('/api/files/<path|.*>', _listFiles)
      ..get('/api/download/<path|.*>', _downloadFile)
      ..post('/api/upload', _uploadFile);

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  /// Set the shared directory for file listing/serving.
  void setSharedDirectory(String path) {
    _sharedDirectory = path;
  }

  /// Stop the server.
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// List files in a directory.
  Future<Response> _listFiles(Request request) async {
    if (_sharedDirectory == null) {
      return Response.ok(
        jsonEncode({'files': [], 'error': 'No shared directory configured'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final path = request.params['path'] ?? '';
    final fullPath = p.join(_sharedDirectory!, path);

    final dir = Directory(fullPath);
    if (!await dir.exists()) {
      return Response.notFound(jsonEncode({'error': 'Directory not found'}));
    }

    // Security: prevent path traversal
    final canonical = p.canonicalize(fullPath);
    if (!canonical.startsWith(p.canonicalize(_sharedDirectory!))) {
      return Response.forbidden(jsonEncode({'error': 'Access denied'}));
    }

    final entries = <Map<String, dynamic>>[];
    await for (final entity in dir.list()) {
      final stat = await entity.stat();
      entries.add({
        'name': p.basename(entity.path),
        'is_dir': entity is Directory,
        'size': stat.size,
        'modified': stat.modified.millisecondsSinceEpoch,
      });
    }

    // Sort: directories first, then alphabetical
    entries.sort((a, b) {
      if (a['is_dir'] != b['is_dir']) {
        return a['is_dir'] ? -1 : 1;
      }
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return Response.ok(
      jsonEncode({

}}}
