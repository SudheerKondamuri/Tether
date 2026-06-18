import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_badge.dart';
import 'package:tether/shared/widgets/tether_button.dart';
import 'package:tether/shared/widgets/tether_text_field.dart';
import 'package:tether/core/database/app_database.dart';
import 'package:tether/core/providers.dart';

/// Clipboard history screen — shows synced clipboard entries.
class ClipboardScreen extends ConsumerStatefulWidget {
  const ClipboardScreen({super.key});

  @override
  ConsumerState<ClipboardScreen> createState() => _ClipboardScreenState();
}

enum _ClipboardFilter { all, local, remote }

class _ClipboardScreenState extends ConsumerState<ClipboardScreen> {
  final _searchController = TextEditingController();
  String _filter = '';
  int? _selectedIndex;
  _ClipboardFilter _activeFilter = _ClipboardFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(clipboardHistoryProvider);

    return Container(
      color: TetherColors.backgroundBase,
      child: historyAsync.when(
        data: (items) {
          final filtered = items.where((item) {
            // Search filter
            if (_filter.isNotEmpty &&
                !item.content.toLowerCase().contains(_filter.toLowerCase())) {
              return false;
            }
            // Category filter
            switch (_activeFilter) {
              case _ClipboardFilter.all:
                return true;
              case _ClipboardFilter.local:
                return item.sourceDevice.toLowerCase() == 'local';
              case _ClipboardFilter.remote:
                return item.sourceDevice.toLowerCase() != 'local';
            }
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ───
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    const Text(
                      'Clipboard',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: TetherColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TetherBadge(
                      label: '${items.length}',
                      color: TetherColors.accentPrimary,
                      isSmall: true,
                    ),
                    const Spacer(),
                    TetherButton(
                      label: 'Clear All',
                      variant: TetherButtonVariant.danger,
                      isSmall: true,
                      onPressed: items.isEmpty
                          ? null
                          : () {
                              ref.read(databaseProvider).clearClipboardEntries();
                              setState(() {
                                _selectedIndex = null;
                              });
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Search ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TetherTextField(
                  controller: _searchController,
                  hint: 'Search clipboard...',
                  prefixIcon: Icons.search,
                  onChanged: (val) => setState(() => _filter = val),
                ),
              ),
              const SizedBox(height: 12),

              // ─── Filter Pills ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _FilterPill(
                      label: 'All',
                      isActive: _activeFilter == _ClipboardFilter.all,
                      onTap: () => setState(() {
                        _activeFilter = _ClipboardFilter.all;
                        _selectedIndex = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Local',
                      isActive: _activeFilter == _ClipboardFilter.local,
                      onTap: () => setState(() {
                        _activeFilter = _ClipboardFilter.local;
                        _selectedIndex = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterPill(
                      label: 'Remote',
                      isActive: _activeFilter == _ClipboardFilter.remote,
                      onTap: () => setState(() {
                        _activeFilter = _ClipboardFilter.remote;
                        _selectedIndex = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── List ───
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected = _selectedIndex == index;
                          return _ClipboardTile(
                            item: item,
                            isSelected: isSelected,
                            onTap: () =>
                                setState(() => _selectedIndex = index),
                            onCopy: () => _copyToClipboard(item.content),
                            onDelete: () {
                              ref.read(databaseProvider).deleteClipboardEntry(item.id);
                              setState(() {
                                _selectedIndex = null;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: TetherColors.accentPrimary),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: TetherColors.accentDanger),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        backgroundColor: TetherColors.surfaceHigher,
      ),
    );
  }
}

class _ClipboardTile extends StatefulWidget {
  final ClipboardEntry item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _ClipboardTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  State<_ClipboardTile> createState() => _ClipboardTileState();
}

class _ClipboardTileState extends State<_ClipboardTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? TetherColors.surfaceHigher
                : _hovering
                    ? TetherColors.surfaceElevated
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isSelected
                ? Border.all(color: TetherColors.accentPrimary.withAlpha(80))
                : null,
          ),
          child: Row(
            children: [
              // Type icon
              Icon(
                _iconForType(widget.item.dataType),
                size: 14,
                color: TetherColors.textSecondary,
              ),
              const SizedBox(width: 10),

              // Content preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.content.length > 120
                          ? '${widget.item.content.substring(0, 120)}...'
                          : widget.item.content,
                      style: TextStyle(
                        fontFamily: widget.item.dataType == 'CODE'
                            ? 'JetBrainsMono'
                            : 'Inter',
                        fontSize: 13,
                        color: TetherColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TetherBadge(
                          label: widget.item.dataType,
                          color: _colorForType(widget.item.dataType),
                          isSmall: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.item.sourceDevice,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: TetherColors.textDisabled,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(widget.item.timestamp),
                          style: TetherTheme.monoSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (_hovering || widget.isSelected) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  color: TetherColors.textSecondary,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: widget.onCopy,
                  tooltip: 'Copy',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14),
                  color: TetherColors.accentDanger,
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  onPressed: widget.onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'URL':
        return Icons.link;
      case 'CODE':
        return Icons.code;
      case 'IMAGE':
        return Icons.image_outlined;
      default:
        return Icons.text_snippet_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type.toUpperCase()) {
      case 'URL':
        return TetherColors.accentPrimary;
      case 'CODE':
        return TetherColors.accentSecondary;
      case 'IMAGE':
        return Colors.amber;
      default:
        return TetherColors.textSecondary;
    }
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
          Icon(Icons.content_paste_outlined,
              size: 48, color: TetherColors.textDisabled),
          const SizedBox(height: 12),
          const Text(
            'No clipboard entries yet',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: TetherColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Copy something on a connected device to see it here',
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

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? TetherColors.surfaceHigher
              : TetherColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? TetherColors.accentPrimary.withAlpha(180)
                : TetherColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? TetherColors.textPrimary : TetherColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
