import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_panel.dart';

/// 声音效果页：调节播放音量，默认音量比标准音量小一些。
class SoundPage extends StatelessWidget {
  const SoundPage({super.key});

  /// 常用的几档音量，省得一点点拖。
  static const List<(String, double)> _presets = [
    ('轻柔', 40),
    ('标准', 60),
    ('响亮', 90),
    ('增强', 130),
  ];

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final volume = player.volume;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('声音效果')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
          children: [
            GlassPanel(
              borderRadius: BorderRadius.circular(24),
              tint: AppColors.card,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                children: [
                  const Text(
                    '播放音量',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        volume.round().toString(),
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '%',
                        style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                  Slider(
                    value: volume.clamp(
                      PlayerService.minVolume,
                      PlayerService.maxVolume,
                    ),
                    min: PlayerService.minVolume,
                    max: PlayerService.maxVolume,
                    onChanged: (value) => player.setVolume(value),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '静音',
                        style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                      ),
                      Text(
                        '标准 100',
                        style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                      ),
                      Text(
                        '最大',
                        style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final preset in _presets)
                        _PresetChip(
                          label: preset.$1,
                          value: preset.$2,
                          active: volume.round() == preset.$2.round(),
                          onTap: () => player.setVolume(preset.$2),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final double value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.cardStrong,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.cardBorder,
            ),
          ),
          child: Text(
            '$label ${value.round()}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.primary : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
