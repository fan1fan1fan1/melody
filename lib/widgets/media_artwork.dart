import 'dart:io';

import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../theme/app_theme.dart';

/// 媒体封面：优先显示文件自己的内嵌封面；没有内嵌封面时，
/// 用「按内容生成」的专属彩色封面兜底，保证每一首都各有各的图。
class MediaArtwork extends StatelessWidget {
  const MediaArtwork({
    super.key,
    required this.kind,
    this.size = 48,
    this.radius = 14,
    this.icon,
    this.glow = false,
    this.artworkPath,
    this.seed,
    this.label,
  });

  final MediaKind kind;
  final double size;
  final double radius;
  final IconData? icon;
  final bool glow;

  /// 内嵌封面的缓存图片路径，为空时显示生成的专属封面。
  final String? artworkPath;

  /// 生成封面用的稳定种子（通常是文件路径）。
  final String? seed;

  /// 生成封面中央显示的字符（通常是标题首字）。
  final String? label;

  /// 音频用音符，视频用胶片。
  static IconData iconOf(MediaKind kind) => kind == MediaKind.audio
      ? Icons.music_note_rounded
      : Icons.movie_creation_rounded;

  static LinearGradient gradientOf(MediaKind kind) => kind == MediaKind.audio
      ? AppColors.audioGradient
      : AppColors.videoGradient;

  @override
  Widget build(BuildContext context) {
    final gradient = gradientOf(kind);
    final path = artworkPath;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: gradient.colors.last.withValues(alpha: 0.45),
                  blurRadius: size * 0.32,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: path == null
          ? (seed == null
                ? _placeholder()
                : GeneratedCover(seed: seed!, label: label ?? ''))
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            ),
    );
  }

  Widget _placeholder() => Center(
    child: Icon(icon ?? iconOf(kind), color: Colors.white, size: size * 0.46),
  );
}

/// 没有内嵌封面时生成的专属封面：按内容哈希决定配色，中央显示标题首字。
/// 同一文件每次都生成同一张图，不同文件之间颜色互不相同。
class GeneratedCover extends StatelessWidget {
  const GeneratedCover({
    super.key,
    required this.seed,
    required this.label,
    this.icon,
  });

  final String seed;
  final String label;
  final IconData? icon;

  /// 稳定哈希（FNV-1a 变体），跨进程结果一致。
  static int stableHash(String input) {
    var hash = 0xcbf29ce484222325;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
    }
    return hash;
  }

  /// 由种子推导出的双色渐变，色相取自哈希、明度固定，保证霓虹深色观感。
  static LinearGradient gradientFor(String seed) {
    final hash = stableHash(seed);
    final hue = (hash % 360).toDouble();
    final second = (hue + 42) % 360;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(1, hue, 0.68, 0.46).toColor(),
        HSLColor.fromAHSL(1, second, 0.72, 0.28).toColor(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = label.isEmpty ? '♪' : label;
    final glyph = icon;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : constraints.maxHeight;
        return DecoratedBox(
          decoration: BoxDecoration(gradient: gradientFor(seed)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _SheenPainter()),
              Center(
                child: glyph == null
                    ? Text(
                        text,
                        style: TextStyle(
                          fontSize: side * 0.44,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.94),
                          height: 1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: side * 0.08,
                              offset: Offset(0, side * 0.02),
                            ),
                          ],
                        ),
                      )
                    : Icon(
                        glyph,
                        size: side * 0.46,
                        color: Colors.white.withValues(alpha: 0.94),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 封面上的柔和高光与暗角，让纯色渐变看起来更像一张图。
class _SheenPainter extends CustomPainter {
  const _SheenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.5, -0.7),
          radius: 1.1,
          colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.6, 0.9),
          radius: 1.2,
          colors: [
            Colors.black.withValues(alpha: 0.28),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SheenPainter oldDelegate) => false;
}
