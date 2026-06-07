import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_badge.dart';
import 'package:tether/shared/widgets/tether_button.dart';
import 'package:tether/shared/widgets/tether_text_field.dart';

/// A clipboard entry for the local ring buffer.
class ClipboardItem {
  final String content;
  final String dataType;
  final String source;
  final DateTime timestamp;

  ClipboardItem({
    required this.content,
    required this.dataType,
    required this.source,
    required this.timestamp,
  });
}

/// Clipboard history screen — shows synced clipboard entries.
class ClipboardScreen extends ConsumerStatefulWidget {
  const ClipboardScreen({super.key});

  @override
  ConsumerState<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends ConsumerState<ClipboardScreen> {
  final List<ClipboardItem> _items = [];
  final _searchController = TextEditingController();
  String _filter = '';
  int? _selectedIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((item) {
      if (_filter.isEmpty) return true;
      return item.content.toLowerCase().contains(_filter.toLowerCase());
    }).toList();

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
                  label: '${_items.length}',
                  color: TetherColors.accentPrimary,
                  isSmall: true,
                ),
                const Spacer(),
                TetherButton(
                  label: 'Clear All',
                  variant: TetherButtonVariant.danger,
                  isSmall: true,
                  onPressed: _items.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _items.clear();
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
                          setState(() {
                            _items.remove(item);
                            _selectedIndex = null;
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
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
  final ClipboardItem item;
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

}
