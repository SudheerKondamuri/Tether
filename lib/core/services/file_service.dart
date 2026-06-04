import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/networking/http_file_server.dart';
import 'package:tether/shared/constants.dart';

/// A file or directory entry in the browser.
class FileItem {
  final String name;
  final int size;
  final bool isDir;
  final DateTime modified;

  FileItem({
    required this.name,
    required this.size,
    required this.isDir,
    required this.modified,
  });
}

/// Manages local HttpFileServer and executes HTTP operations on the peer's file server.
class FileService {
  final ConnectionManager _connectionManager;
  final HttpFileServer _fileServer = HttpFileServer();
  String _sharedDirectory = '';

  String get sharedDirectory => _sharedDirectory;

  final _transferProgressController = StreamController<double>.broadcast();
  Stream<double> get transferProgressStream => _transferProgressController.stream;

  FileService({
    required ConnectionManager connectionManager,
  }) : _connectionManager = connectionManager;

  /// Initialize and start local file server.
  Future<void> start() async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
    _sharedDirectory = dir.path;

    await _fileServer.start(
      sharedDirectory: _sharedDirectory,
      port: TetherConstants.httpFilePort,
    );
  }

  /// Change local shared directory.
  void setSharedDirectory(String path) {
    _sharedDirectory = path;
    _fileServer.setSharedDirectory(path);
  }

  /// Stop local file server.
  Future<void> stop() async {
    await _fileServer.stop();
  }

  /// List files on the remote peer's file server.
  Future<List<FileItem>> listRemoteFiles(String path) async {
    final peer = _connectionManager.peer;
    if (peer == null) throw Exception('No peer connected');

    final client = HttpClient();
    try {
      final cleanPath = path == 'root' || path.isEmpty ? '' : path;
      final uri = Uri.parse('http://${peer.ip}:${TetherConstants.httpFilePort}/api/files/$cleanPath');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Server returned status ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final filesData = data['files'] as List<dynamic>? ?? [];

      return filesData.map((f) {
        return FileItem(
          name: f['name'] as String? ?? 'unnamed',
          size: f['size'] as int? ?? 0,
          isDir: f['is_dir'] as bool? ?? false,
          modified: DateTime.fromMillisecondsSinceEpoch(f['modified'] as int? ?? 0),
        );
      }).toList();
    } finally {
      client.close();
    }
  }

  /// Download a file from the remote peer's file server.
  Future<void> downloadFile(String remoteRelativePath, String localDestPath) async {
    final peer = _connectionManager.peer;
    if (peer == null) throw Exception('No peer connected');

    final client = HttpClient();
    try {
      final uri = Uri.parse('http://${peer.ip}:${TetherConstants.httpFilePort}/api/download/$remoteRelativePath');
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Server returned status ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      final file = File(localDestPath);
      final sink = file.openWrite();

      int bytesReceived = 0;
      _transferProgressController.add(0.0);

      await response.forEach((chunk) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0) {
          _transferProgressController.add(bytesReceived / contentLength);
        }
      });

      await sink.close();
      _transferProgressController.add(1.0);
    } catch (e) {
      _transferProgressController.add(-1.0);
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Upload a file to the remote peer's file server.
  Future<void> uploadFile(File localFile) async {
    final peer = _connectionManager.peer;
    if (peer == null) throw Exception('No peer connected');

    final filename = p.basename(localFile.path);
    final size = await localFile.length();

    final client = HttpClient();
    try {
      final uri = Uri.parse('http://${peer.ip}:${TetherConstants.httpFilePort}/api/upload');
      final request = await client.postUrl(uri);
      
      request.headers.set('X-Filename', filename);
      request.contentLength = size;

      int bytesSent = 0;
      _transferProgressController.add(0.0);

      final fileStream = localFile.openRead();
      final requestSink = request;

      await for (final chunk in fileStream) {
        requestSink.add(chunk);
        bytesSent += chunk.length;
        if (size > 0) {
          _transferProgressController.add(bytesSent / size);
        }
      }

      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Server returned status ${response.statusCode}');
      }

      _transferProgressController.add(1.0);
    } catch (e) {
      _transferProgressController.add(-1.0);
      rethrow;
    } finally {
      client.close();
    }
  }

  void dispose() {
    stop();
    _transferProgressController.close();
  }
}

// ─── Riverpod Providers ───

final fileServiceProvider = Provider<FileService>((ref) {
  final connManager = ref.watch(connectionManagerProvider);
  final service = FileService(connectionManager: connManager);
  ref.onDispose(() => service.dispose());
  return service;
});
