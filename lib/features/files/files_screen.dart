import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_button.dart';
import 'package:tether/core/services/file_service.dart';
import 'package:tether/core/networking/connection_manager.dart';

/// File browser screen — browse remote device files.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  final List<FileItem> _files = [];
  final List<String> _breadcrumbs = ['root'];
  int? _selectedIndex;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFiles();
    });
  }

  Future<void> _loadFiles() async {
    final connectionState = ref.read(connectionStateProvider).valueOrNull;
    if (connectionState != TetherConnectionState.connected) {
      setState(() {
        _files.clear();
        _error = 'No device connected';
        _selectedIndex = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _selectedIndex = null;
    });

    try {
      final currentPath = _breadcrumbs.sublist(1).join('/');
      final service = ref.read(fileServiceProvider);
      final files = await service.listRemoteFiles(currentPath);
      if (mounted) {
        setState(() {
          _files.clear();
          _files.addAll(files);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _downloadSelectedFile() async {
    if (_selectedIndex == null) return;
    final file = _files[_selectedIndex!];
    
    final currentPath = _breadcrumbs.sublist(1).join('/');
    final remoteRelativePath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
    
    final service = ref.read(fileServiceProvider);
    final localDestPath = p.join(service.sharedDirectory, file.name);

    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Downloading ${file.name} to local downloads folder...'),
        backgroundColor: TetherColors.accentPrimary,
      ),
    );

    try {
      await service.downloadFile(remoteRelativePath, localDestPath);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Downloaded ${file.name} successfully!'),
          backgroundColor: TetherColors.accentSecondary,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: TetherColors.accentDanger,
        ),
      );
    }
  }

  Future<void> _showSendFileDialog() async {
    final controller = TextEditingController();
    final service = ref.read(fileServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: TetherColors.surfaceHigher,
          title: const Text('Send File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter local absolute path:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: TetherColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: TetherColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: Platform.isAndroid
                      ? '/storage/emulated/0/Download/file.txt'
                      : '/home/omni/Downloads/file.txt',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final path = controller.text.trim();
                if (path.isEmpty) return;
                
                final navigator = Navigator.of(dialogContext);
                final file = File(path);
                final fileExists = await file.exists();

                if (!fileExists) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('File does not exist! Check path.'),
                      backgroundColor: TetherColors.accentDanger,
                    ),
                  );
                  return;
                }

                navigator.pop();
                
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Uploading ${p.basename(path)}...'),
                    backgroundColor: TetherColors.accentPrimary,
                  ),
                );

                try {
                  await service.uploadFile(file);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Uploaded ${p.basename(path)} successfully!'),
                      backgroundColor: TetherColors.accentSecondary,
                    ),
                  );
                  _loadFiles();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      backgroundColor: TetherColors.accentDanger,
                    ),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider).valueOrNull;
    final isConnected = connectionState == TetherConnectionState.connected;

    if (!isConnected) {
      return Container(
        color: TetherColors.backgroundBase,
        child: const _EmptyState(message: 'Connect a device to browse and transfer files'),
      );
    }

    return Container(
      color: TetherColors.backgroundBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                const Text(
                  'Files',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: TetherColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_selectedIndex != null && !_files[_selectedIndex!].isDir) ...[
                  TetherButton(
                    label: 'Download',
                    icon: Icons.download_outlined,
                    isSmall: true,
                    onPressed: _downloadSelectedFile,
                  ),
                  const SizedBox(width: 8),
                ],
                TetherButton(
                  label: 'Send File',
                  icon: Icons.upload_file_outlined,
                  isSmall: true,
                  onPressed: _showSendFileDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ─── Breadcrumbs ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: TetherColors.surfaceElevated,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _breadcrumbs.length; i++) ...[
                    if (i > 0)
                      const Text(
                        ' / ',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: TetherColors.textDisabled,
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _breadcrumbs.removeRange(i + 1, _breadcrumbs.length);
                          _selectedIndex = null;
                        });
                        _loadFiles();
                      },
                      child: Text(
                        _breadcrumbs[i],
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,

}}
