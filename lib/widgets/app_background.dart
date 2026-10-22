import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 统一的深夜渐变背景，叠上柔和的霓虹光晕。
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.pageBackground),
      child: Stack(
        children: [
          const Positioned(
            top: -120,
            left: -90,
            child: _Glow(color: AppColors.primary, size: 300, opacity: 0.34),
          ),
          const Positioned(
            bottom: -140,
            right: -80,
            child: _Glow(color: AppColors.accent, size: 320, opacity: 0.28),
          ),
          const Positioned(
            top: 260,
            right: -110,
            child: _Glow(
              color: AppColors.videoAccent,
              size: 260,
              opacity: 0.16,
            ),
          ),
          if (child != null) Positioned.fill(child: child!),
        ],
      ),
    );
  }
}

/// 音乐 / 视频 / 白噪音页背景里淡淡的软件 logo 光碟水印。
class LogoWatermark extends StatelessWidget {
  const LogoWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth * 0.66;
          return Align(
            alignment: const Alignment(0, -0.15),
            child: Opacity(
              opacity: 0.12,
              child: ClipOval(
                child: Image.asset(
                  '1.jpg',
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 一团模糊的霓虹光晕。
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
