import 'package:flutter/material.dart';

/// 光碟（CD）样式的媒体入口：碟面为封面图案，中心为金属轴心与中孔，播放时缓缓旋转。
class DiscCard extends StatefulWidget {
  const DiscCard({
    super.key,
    required this.size,
    required this.spinning,
    required this.rimColors,
    this.cover,
  });

  final double size;

  /// 是否正在播放（播放时碟片缓缓旋转）。
  final bool spinning;

  /// 霓虹外圈颜色。
  final List<Color> rimColors;

  /// 碟面图案（文件夹封面或应用图标）。
  final ImageProvider? cover;

  @override
  State<DiscCard> createState() => _DiscCardState();
}

class _DiscCardState extends State<DiscCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant DiscCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spinning != widget.spinning) _syncSpin();
  }

  void _syncSpin() {
    if (widget.spinning) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.rimColors.first.withValues(alpha: 0.35),
            blurRadius: size * 0.18,
            spreadRadius: -size * 0.02,
            offset: Offset(0, size * 0.07),
          ),
        ],
      ),
      child: ClipOval(
        child: RotationTransition(
          turns: _controller,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _face(size),
              CustomPaint(painter: const _DiscFacePainter()),
              Center(child: _DiscHub(size: size)),
            ],
          ),
        ),
      ),
    );
  }

  /// 碟面底图：有封面时铺满碟面，否则为银色碟片。
  Widget _face(double size) {
    final provider = widget.cover;
    if (provider == null) return const _SilverFace();
    return Image(
      image: provider,
      fit: BoxFit.cover,
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) => const _SilverFace(),
    );
  }
}

/// 无封面时的银色碟面。
class _SilverFace extends StatelessWidget {
  const _SilverFace();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFFDFDFF), Color(0xFFE3E4EA), Color(0xFFBFC1CC)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
    );
  }
}

/// 中心金属轴心与中孔。
class _DiscHub extends StatelessWidget {
  const _DiscHub({required this.size});

  /// 碟片整体直径。
  final double size;

  @override
  Widget build(BuildContext context) {
    final hub = size * 0.34;
    final hole = size * 0.1;
    return SizedBox(
      width: hub,
      height: hub,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEDEDF2), Color(0xFFC6C7CF), Color(0xFF9A9BA6)],
            stops: [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: hub * 0.76,
              height: hub * 0.76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
            Container(
              width: hole,
              height: hole,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1822),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 绘制碟面纹路、虹彩反光与外圈高光。
class _DiscFacePainter extends CustomPainter {
  const _DiscFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 碟面细密纹路。
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.055);
    for (var r = radius * 0.34; r < radius * 0.99; r += radius * 0.018) {
      canvas.drawCircle(center, r, groove);
    }

    // 虹彩反光带（外圈）。
    final iridescence = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius * 0.99))
      ..addOval(Rect.fromCircle(center: center, radius: radius * 0.5))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      iridescence,
      Paint()
        ..shader = SweepGradient(
          colors: [
            const Color(0x00FFFFFF),
            const Color(0x33F7C7FF),
            const Color(0x2233E1FF),
            const Color(0x22FFE27A),
            const Color(0x33FF7AD9),
            const Color(0x00FFFFFF),
          ],
        ).createShader(rect),
    );

    // 轴心外圈塑料环。
    canvas.drawCircle(
      center,
      radius * 0.37,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.014
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // 斜向高光。
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.24), Colors.transparent],
          stops: const [0.0, 0.46],
        ).createShader(rect),
    );

    // 外圈边缘高光。
    canvas.drawCircle(
      center,
      radius * 0.995,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.02
        ..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _DiscFacePainter oldDelegate) => false;
}
