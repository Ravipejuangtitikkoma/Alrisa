import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/services/preset_manager_service.dart';

/// Scene / Preset Chips Horizontal
/// Mengambil data skenario secara dinamis & real-time dari PresetManagerService
class SceneChips extends StatelessWidget {
  final ValueChanged<String>? onSceneSelected;

  const SceneChips({Key? key, this.onSceneSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PresetSceneItem>>(
      stream: PresetManagerService().presetsStream,
      initialData: PresetManagerService().allPresets,
      builder: (context, snapshot) {
        final presets = snapshot.data ?? [];

        if (presets.isEmpty) {
          return Container(
            height: 44,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Belum ada preset tersimpan',
              style: TextStyle(
                fontFamily: NexoraTokens.fontFamilySans,
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: presets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isActive = preset.isActive;
              final accentColor = preset.accentColor;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final nextState = !isActive;
                    await PresetManagerService().togglePreset(preset.id, nextState);
                    onSceneSelected?.call(preset.id);

                    try {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: nextState ? const Color(0xFF0F172A) : const Color(0xFF334155),
                          duration: const Duration(seconds: 2),
                          content: Row(
                            children: [
                              Icon(
                                nextState ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: nextState ? accentColor : Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  nextState
                                      ? 'Preset "${preset.name}" aktif!'
                                      : 'Preset dinonaktifkan (Mode Manual)',
                                  style: const TextStyle(
                                    fontFamily: NexoraTokens.fontFamilySans,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } catch (_) {}
                  },
                  borderRadius: NexoraTokens.borderRadiusChip,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? accentColor.withValues(alpha: 0.18) : Colors.white,
                      borderRadius: NexoraTokens.borderRadiusChip,
                      border: Border.all(
                        color: isActive ? accentColor : const Color(0xFFE2E8F0),
                        width: isActive ? 1.6 : 1.0,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : NexoraTokens.cardShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          preset.icon,
                          size: 17,
                          color: isActive ? accentColor : NexoraTokens.inkSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          preset.name,
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 12.5,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                            color: isActive ? accentColor : NexoraTokens.ink,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
