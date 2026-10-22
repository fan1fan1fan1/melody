import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 磨砂毛玻璃面板。
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blur = 22,
    this.tint = AppColors.glass,
    this.padding = EdgeInsets.zero,
    this.border,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color tint;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}
