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

/// Currently selected navigation index.
final selectedNavProvider = StateProvider<int>((ref) => 0);

/// Linux desktop three-column shell layout.
class LinuxShell extends ConsumerWidget {
  const LinuxShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNav = ref.watch(selectedNavProvider);

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
                    child: _buildContent(selectedNav),
                  ),

}}
