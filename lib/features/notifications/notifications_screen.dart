import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_badge.dart';
import 'package:tether/core/services/notification_bridge_service.dart';

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
  final TetherNotification notif;

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

    if (widget.notif.iconBase64 != null) {
      try {
        final bytes = base64Decode(widget.notif.iconBase64!);
        iconWidget = Image.memory(
          bytes,
          width: 16,
          height: 16,
          fit: BoxFit.cover,
        );

}}}}
