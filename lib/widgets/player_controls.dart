import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 播放控制里用的普通图标按钮。
class PlayerIconButton extends StatelessWidget {
  const PlayerIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.iconSize = 22,
    this.buttonSize = 40,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final double iconSize;
  final double buttonSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        splashRadius: buttonSize * 0.6,
        iconSize: iconSize,
        onPressed: enabled ? onTap : null,
        icon: Icon(
          icon,
          color: enabled ? color : AppColors.inkSoft.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// 播放 / 暂停主按钮（渐变圆形）。
class PlayerPlayButton extends StatelessWidget {
  const PlayerPlayButton({
    super.key,
    required this.playing,
    required this.onTap,
    this.size = 44,
  });

  final bool playing;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.34),
              blurRadius: size * 0.36,
              offset: Offset(0, size * 0.14),
            ),
          ],
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * 0.52,
        ),
      ),
    );
  }
}

/// 胶囊形状的小功能按钮（倍速、播放列表等）。
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.22)
                : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.primary : AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
