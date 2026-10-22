import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// 进度条，支持拖动结束后跳转。
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.showTime = false,
    this.compact = false,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final bool showTime;
  final bool compact;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds.toDouble();
    final max = total <= 0 ? 1.0 : total;
    final current = (_dragValue ?? widget.position.inMilliseconds.toDouble())
        .clamp(0.0, max);
    final currentDuration = Duration(milliseconds: current.round());

    final slider = Slider(
      value: current,
      max: max,
      onChanged: total <= 0
          ? null
          : (value) => setState(() => _dragValue = value),
      onChangeEnd: total <= 0
          ? null
          : (value) {
              setState(() => _dragValue = null);
              widget.onSeek(Duration(milliseconds: value.round()));
            },
    );

    if (!widget.showTime) {
      return SizedBox(
        height: widget.compact ? 22 : 28,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            inactiveTrackColor: AppColors.primary.withValues(alpha: 0.26),
          ),
          child: slider,
        ),
      );
    }

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: slider,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(currentDuration),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              Text(
                formatDuration(widget.duration),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
