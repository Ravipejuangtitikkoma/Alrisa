import 'package:flutter/material.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/data/mock_home.dart';

/// Scene Chips Horizontal
class SceneChips extends StatefulWidget {
  final ValueChanged<String>? onSceneSelected;

  const SceneChips({Key? key, this.onSceneSelected}) : super(key: key);

  @override
  _SceneChipsState createState() => _SceneChipsState();
}

class _SceneChipsState extends State<SceneChips> {
  late List<SceneModel> _scenes;

  @override
  void initState() {
    super.initState();
    _scenes = MockHomeData.getScenes();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _scenes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final scene = _scenes[index];
          final isSelected = scene.isSelected;

          return GestureDetector(
            onTap: () {
              setState(() {
                for (var s in _scenes) {
                  s.isSelected = (s.id == scene.id);
                }
              });
              widget.onSceneSelected?.call(scene.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
                borderRadius: NexoraTokens.borderRadiusChip,
                border: Border.all(
                  color: isSelected ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                  width: 1.0,
                ),
                boxShadow: isSelected ? [] : NexoraTokens.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    scene.icon,
                    size: 16,
                    color: isSelected ? NexoraTokens.brandCyan : NexoraTokens.inkSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    scene.title,
                    style: TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? NexoraTokens.brandCyan : NexoraTokens.ink,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
