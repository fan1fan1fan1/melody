import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_panel.dart';

/// 一条白噪音：名称、内置音频文件名与图标。
/// 音频文件之后放进 assets/noise/ 目录即可。
class NoiseTrack {
  const NoiseTrack(this.name, this.file, this.icon);

  final String name;
  final String file;
  final IconData icon;

  String get asset => 'assets/noise/$file';
}

/// 白噪音页：音频随软件一起提供，暂时只做按钮。
class NoisePage extends StatelessWidget {
  const NoisePage({super.key});

  static const List<NoiseTrack> tracks = [
    NoiseTrack('下雨', 'rain.mp3', Icons.water_drop_rounded),
    NoiseTrack('海浪', 'waves.mp3', Icons.waves_rounded),
    NoiseTrack('音叉', 'tuning_fork.mp3', Icons.graphic_eq_rounded),
    NoiseTrack('图书馆', 'library.mp3', Icons.local_library_rounded),
    NoiseTrack('敲击', 'tapping.mp3', Icons.touch_app_rounded),
    NoiseTrack('耳烛', 'ear_candle.mp3', Icons.hearing_rounded),
    NoiseTrack('篝火', 'campfire.mp3', Icons.local_fire_department_rounded),
    NoiseTrack('喷雾', 'spray.mp3', Icons.blur_on_rounded),
    NoiseTrack('时钟', 'clock.mp3', Icons.schedule_rounded),
    NoiseTrack('森林', 'forest.mp3', Icons.park_rounded),
    NoiseTrack('蝉鸣', 'cicada.mp3', Icons.grass_rounded),
    NoiseTrack('流水溪流', 'stream.mp3', Icons.opacity_rounded),
  ];

  void _onTap(BuildContext context, NoiseTrack track) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('「${track.name}」的音频还没导入'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: LogoWatermark()),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '白噪音',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.86,
                            ),
                        itemCount: tracks.length,
                        itemBuilder: (context, index) => _NoiseTile(
                          track: tracks[index],
                          onTap: () => _onTap(context, tracks[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoiseTile extends StatelessWidget {
  const _NoiseTile({required this.track, required this.onTap});

  final NoiseTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(20),
      blur: 18,
      tint: AppColors.card,
      border: Border.all(color: AppColors.cardBorder),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.noise.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.noise.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(track.icon, size: 24, color: AppColors.noise),
              ),
              const SizedBox(height: 10),
              Text(
                track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
