import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_badge.dart';
import 'package:tether/core/services/notification_bridge_service.dart';
import 'package:tether/core/database/app_database.dart';

/// Notification mirror screen.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Container(
      color: TetherColors.backgroundBase,
      child: notificationsAsync.when(
        data: (notifications) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: TetherColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TetherBadge(
                      label: '${notifications.length}',
                      color: TetherColors.accentPrimary,
                      isSmall: true,
                    ),
                    const Spacer(),
                    if (notifications.isNotEmpty)
                      TextButton(
                        onPressed: () => ref.read(notificationBridgeProvider).clearAll(),
                        child: const Text(
                          'Clear all',
                          style: TextStyle(
                            fontSize: 12,
                            color: TetherColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Notification List ───
              Expanded(
                child: notifications.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          return _NotificationTile(notif: notif);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: TetherColors.accentPrimary),
        ),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(color: TetherColors.accentDanger),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  final NotificationHistoryData notif;

  const _NotificationTile({required this.notif});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _hovering = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = const Icon(
      Icons.apps,
      size: 16,
      color: TetherColors.textSecondary,
    );

    if (widget.notif.iconB64 != null) {
      try {
        final bytes = base64Decode(widget.notif.iconB64!);
        iconWidget = Image.memory(
          bytes,
          width: 16,
          height: 16,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovering
                ? TetherColors.surfaceHigher
                : TetherColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: TetherColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: TetherColors.surfaceHigher,
                    ),
                    alignment: Alignment.center,
                    child: iconWidget,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.notif.appName,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: TetherColors.textSecondary,
                          ),
                        ),
                        Text(
                          widget.notif.title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: TetherColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTime(widget.notif.timestamp),
                    style: TetherTheme.monoSmall,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.notif.body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: TetherColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_outlined,
              size: 48, color: TetherColors.textDisabled),
          const SizedBox(height: 12),
          const Text(
            'No notifications',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: TetherColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Notifications from the connected Android device appear here',
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
