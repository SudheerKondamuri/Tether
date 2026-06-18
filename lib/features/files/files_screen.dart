import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_button.dart';
import 'package:tether/core/services/file_service.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/core/providers.dart';
import 'package:file_picker/file_picker.dart';

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

    ref.read(selectedFileDetailProvider.notifier).state = null;
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
  }  Future<void> _showSendFileDialog() async {
    final service = ref.read(fileServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) {
        throw Exception('Cannot access local file path');
      }

      final file = File(path);
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('Uploading ${p.basename(path)}...'),
          backgroundColor: TetherColors.accentPrimary,
        ),
      );

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
  }


  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<TetherConnectionState>>(
      connectionStateProvider,
      (prev, next) {
        if (next.value == TetherConnectionState.connected) {
          _loadFiles();
        }
      },
    );

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
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  color: TetherColors.textSecondary,
                  onPressed: _loadFiles,
                  tooltip: 'Refresh',
                ),
                const SizedBox(width: 8),
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
                        ref.read(selectedFileDetailProvider.notifier).state = null;
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
                          color: i == _breadcrumbs.length - 1
                              ? TetherColors.textPrimary
                              : TetherColors.accentPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── File List ───
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: TetherColors.accentPrimary),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Error loading files: $_error',
                              style: const TextStyle(color: TetherColors.accentDanger),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TetherButton(
                              label: 'Retry',
                              onPressed: _loadFiles,
                              isSmall: true,
                            ),
                          ],
                        ),
                      )
                    : _files.isEmpty
                        ? const _EmptyState(message: 'This directory is empty')
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _files.length,
                            itemBuilder: (context, index) {
                              final file = _files[index];
                              return _FileTile(
                                file: file,
                                isSelected: _selectedIndex == index,
                                onTap: () {
                                  if (file.isDir) {
                                    ref.read(selectedFileDetailProvider.notifier).state = null;
                                    setState(() {
                                      _breadcrumbs.add(file.name);
                                      _selectedIndex = null;
                                    });
                                    _loadFiles();
                                  } else {
                                    setState(() => _selectedIndex = index);
                                    final currentPath = _breadcrumbs.sublist(1).join('/');
                                    final remoteRelativePath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
                                    ref.read(selectedFileDetailProvider.notifier).state = SelectedFileDetail(
                                      file: file,
                                      remotePath: remoteRelativePath,
                                    );
                                  }
                                },
                              );
                            },
                          ),
          ),

          // ─── Transfer Bar ───
          StreamBuilder<double>(
            stream: ref.watch(fileServiceProvider).transferProgressStream,
            initialData: 1.0,
            builder: (context, snapshot) {
              final progress = snapshot.data ?? 1.0;
              final isTransferring = progress >= 0.0 && progress < 1.0;
              final isFailed = progress == -1.0;
              
              String text = 'No active transfer';
              if (isTransferring) {
                text = 'Transferring... ${(progress * 100).toStringAsFixed(0)}%';
              } else if (isFailed) {
                text = 'Transfer failed!';
              } else if (progress == 1.0) {
                text = 'Ready';
              }

              return Container(
                height: 36,
                decoration: const BoxDecoration(
                  color: TetherColors.surfaceElevated,
                  border: Border(
                    top: BorderSide(color: TetherColors.borderSubtle),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isFailed
                            ? TetherColors.accentDanger
                            : isTransferring
                                ? TetherColors.accentSecondary
                                : TetherColors.textDisabled,
                      ),
                    ),
                    if (isTransferring) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: TetherColors.borderSubtle,
                            color: TetherColors.accentSecondary,
                            minHeight: 4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FileTile extends StatefulWidget {
  final FileItem file;
  final bool isSelected;
  final VoidCallback onTap;

  const _FileTile({
    required this.file,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? TetherColors.surfaceHigher
                : _hovering
                    ? TetherColors.surfaceElevated
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                widget.file.isDir
                    ? Icons.folder
                    : _fileIcon(widget.file.name),
                size: 16,
                color: widget.file.isDir
                    ? TetherColors.accentPrimary
                    : TetherColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.file.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: TetherColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  widget.file.isDir ? '--' : _formatSize(widget.file.size),
                  style: TetherTheme.monoSmall,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 80,
                child: Text(
                  _formatDate(widget.file.modified),
                  style: TetherTheme.monoSmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'apk':
        return Icons.android;
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
        return Icons.code;
      case 'mp4':
      case 'mkv':
        return Icons.videocam_outlined;
      case 'zip':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}K';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}M';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}G';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_outlined,
              size: 48, color: TetherColors.textDisabled),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: TetherColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use the toolbar to send or manage files',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: TetherColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selected file details class for the side detail panel
class SelectedFileDetail {
  final FileItem file;
  final String remotePath;
  SelectedFileDetail({required this.file, required this.remotePath});
}

final selectedFileDetailProvider = StateProvider<SelectedFileDetail?>((ref) => null);
