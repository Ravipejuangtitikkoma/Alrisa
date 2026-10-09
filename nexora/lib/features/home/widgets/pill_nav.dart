import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/language_service.dart';

/// Floating Pill Nav 4 Item
class PillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const PillNav({
    Key? key,
    required this.currentIndex,
    required this.onIndexChanged,
  }) : super(key: key);

  List<Map<String, dynamic>> _getItems() {
    final lang = LanguageService();
    return [
      {'title': lang.tr('nav_home'), 'icon': Icons.home_outlined},
      {'title': lang.tr('nav_rooms'), 'icon': Icons.grid_view_outlined},
      {'title': lang.tr('nav_energy'), 'icon': Icons.bolt_outlined},
      {'title': lang.tr('nav_settings'), 'icon': Icons.settings_outlined},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _getItems();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: NexoraTokens.surface,
        borderRadius: NexoraTokens.borderRadiusPill,
        border: Border.all(color: NexoraTokens.cardBorder),
        boxShadow: NexoraTokens.pillNavShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (index) {
          final isSelected = index == currentIndex;
          final item = items[index];

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onIndexChanged(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 12 : 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? NexoraTokens.brandCyanSubtle : Colors.transparent,
                borderRadius: NexoraTokens.borderRadiusPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 19,
                    color: isSelected ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        fontFamily: NexoraTokens.fontFamilySans,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NexoraTokens.brandCyan,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
