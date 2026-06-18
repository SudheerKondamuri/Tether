import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/features/shell/title_bar.dart';
import 'package:tether/features/shell/nav_sidebar.dart';
import 'package:tether/features/shell/status_bar.dart';
import 'package:tether/features/dashboard/dashboard_screen.dart';
import 'package:tether/features/clipboard/clipboard_screen.dart';
import 'package:tether/features/files/files_screen.dart';
import 'package:tether/features/notifications/notifications_screen.dart';
import 'package:tether/features/mirror/mirror_screen.dart';
import 'package:tether/features/settings/settings_screen.dart';
import 'package:tether/core/networking/connection_manager.dart';
import 'package:tether/shared/widgets/disconnected_overlay.dart';
import 'package:path/path.dart' as p;
import 'package:tether/core/services/file_service.dart';
import 'package:tether/shared/widgets/tether_button.dart';

/// Currently selected navigation index.
final selectedNavProvider = StateProvider<int>((ref) => 0);

/// Linux desktop three-column shell layout.
class LinuxShell extends ConsumerWidget {
  const LinuxShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNav = ref.watch(selectedNavProvider);
    final connectionAsync = ref.watch(connectionStateProvider);
    final connState = connectionAsync.valueOrNull ?? TetherConnectionState.disconnected;
    final isConnected = connState == TetherConnectionState.connected;

    return Scaffold(
      body: Column(
        children: [
          // ─── Title Bar ───
          const TitleBar(),

          // ─── Main Content Area ───
          Expanded(
            child: Row(
              children: [
                // ─── Left Sidebar ───
                const NavSidebar(),

                // ─── Vertical divider ───
                Container(
                  width: 1,
                  color: TetherColors.borderSubtle,
                ),

                // ─── Main Content Panel ───
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) {
                      final offset = Tween<Offset>(
                        begin: const Offset(0, 0.02),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ));
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offset,
                          child: child,
                        ),
                      );
                    },
                    child: _buildContent(selectedNav, isConnected, ref),
                  ),
                ),

                // ─── Vertical divider ───
                Container(
                  width: 1,
                  color: TetherColors.borderSubtle,
                ),

                // ─── Right Detail Panel ───
                SizedBox(
                  width: 280,
                  child: _buildDetailPanel(context, ref),
                ),
              ],
            ),
          ),

          // ─── Status Bar ───
          const StatusBar(),
        ],
      ),
    );
  }

  Widget _buildContent(int index, bool isConnected, WidgetRef ref) {
    switch (index) {
      case 0:
        return const DashboardScreen(key: ValueKey(0));
      case 1:
        return isConnected
            ? const ClipboardScreen(key: ValueKey(1))
            : DisconnectedOverlay(
                key: const ValueKey('clip_lock'),
                featureName: 'Clipboard History',
                actionLabel: 'Go to Settings',
                onAction: () => ref.read(selectedNavProvider.notifier).state = 5,
              );
      case 2:
        return isConnected
            ? const FilesScreen(key: ValueKey(2))
            : DisconnectedOverlay(
                key: const ValueKey('files_lock'),
                featureName: 'Shared Files',
                actionLabel: 'Go to Settings',
                onAction: () => ref.read(selectedNavProvider.notifier).state = 5,
              );
      case 3:
        return isConnected
            ? const NotificationsScreen(key: ValueKey(3))
            : DisconnectedOverlay(
                key: const ValueKey('notif_lock'),
                featureName: 'Notifications',
                actionLabel: 'Go to Settings',
                onAction: () => ref.read(selectedNavProvider.notifier).state = 5,
              );
      case 4:
        return isConnected
            ? const MirrorScreen(key: ValueKey(4))
            : DisconnectedOverlay(
                key: const ValueKey('mirror_lock'),
                featureName: 'Screen Mirroring',
                actionLabel: 'Go to Settings',
                onAction: () => ref.read(selectedNavProvider.notifier).state = 5,
              );
      case 5:
        return const SettingsScreen(key: ValueKey(5));
      default:
        return const DashboardScreen(key: ValueKey(0));
    }
  }

  Widget _buildDetailPanel(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(selectedFileDetailProvider);
    if (detail == null) {
      return Container(
        color: TetherColors.surfaceElevated,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DETAIL',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select an item to view details',
              style: TextStyle(
                fontSize: 13,
                color: TetherColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final file = detail.file;
    final formattedSize = _formatSize(file.size);
    final formattedDate = _formatDate(file.modified);

    return Container(
      color: TetherColors.surfaceElevated,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETAIL',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 24),
          Center(
            child: Icon(
              _fileIcon(file.name),
              size: 64,
              color: TetherColors.accentPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            file.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: TetherColors.textPrimary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Divider(color: TetherColors.borderSubtle),
          const SizedBox(height: 12),
          _detailRow('Size', formattedSize),
          const SizedBox(height: 12),
          _detailRow('Modified', formattedDate),
          const SizedBox(height: 12),
          _detailRow('Remote Path', detail.remotePath),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: TetherButton(
              label: 'Download / Save',
              icon: Icons.download_outlined,
              onPressed: () async {
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
                  await service.downloadFile(detail.remotePath, localDestPath);
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: TetherColors.textDisabled,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: TetherColors.textSecondary,
            fontFamily: 'JetBrainsMono',
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
