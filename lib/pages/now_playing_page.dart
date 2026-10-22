import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/glass_panel.dart';
import '../widgets/media_artwork.dart';
import '../widgets/media_tile.dart';
import '../widgets/player_controls.dart';
import '../widgets/seek_bar.dart';

/// 从底部拉起的播放详情抽屉（下拉关闭）。
Future<void> openNowPlaying(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const NowPlayingSheet(),
  );
}

/// 播放详情抽屉：半透明毛玻璃面板，顶部有拖动条，下方是封面与全部控制。
class NowPlayingSheet extends StatelessWidget {
  const NowPlayingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final item = context.select<PlayerService, MediaItem?>((p) => p.current);
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GlassPanel(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        tint: AppColors.glass,
        blur: 30,
        border: const Border(top: BorderSide(color: Color(0x33FFFFFF))),
        child: SizedBox(
          width: double.infinity,
          height: screenHeight * 0.92,
          child: Column(
            children: [
              const _DragHandle(),
              _SheetHeader(item: item),
              Expanded(
                child: item == null
                    ? const Center(
                        child: Text(
                          '还没有选择要播放的文件',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      )
                    : item.kind == MediaKind.audio
                    ? const _AudioBody()
                    : const _VideoBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 抽屉顶部的拖动条（下拉即可关闭）。
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// 抽屉标题栏：正在播放 + 类型 + 收起按钮。
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.item});

  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 18, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: '退出播放页',
            icon: const Icon(Icons.close_rounded, size: 24),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '正在播放',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                item == null
                    ? '暂无内容'
                    : (item!.kind == MediaKind.audio ? '音乐' : '视频'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// 音频播放界面。
class _AudioBody extends StatefulWidget {
  const _AudioBody();

  @override
  State<_AudioBody> createState() => _AudioBodyState();
}

class _AudioBodyState extends State<_AudioBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final item = player.current!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final max = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 220.0;
                final side = (max - 26).clamp(140.0, 250.0);
                return Center(
                  child: _CoverFrame(item: item, side: side),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            item.artist ?? '未知作者',
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          _ControlCluster(
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
    );
  }
}

/// 视频播放界面。
class _VideoBody extends StatefulWidget {
  const _VideoBody();

  @override
  State<_VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<_VideoBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final item = player.current!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Video(
                          controller: player.videoController,
                          fit: BoxFit.contain,
                          fill: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.artist ?? '未知作者',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ControlCluster(
            compact: true,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
    );
  }
}

/// 封面外框：一层半透明玻璃框，里面才是封面图，整体比之前更小更含蓄。
class _CoverFrame extends StatelessWidget {
  const _CoverFrame({required this.item, required this.side});

  final MediaItem item;
  final double side;

  @override
  Widget build(BuildContext context) {
    final gradient = MediaArtwork.gradientOf(item.kind);
    final path = item.artworkPath;
    final generated = GeneratedCover(seed: item.path, label: item.coverInitial);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: 0.34),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: SizedBox(
        width: side,
        height: side,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: path == null
              ? generated
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => generated,
                ),
        ),
      ),
    );
  }
}

String _rateLabel(double rate) {
  if (rate == rate.roundToDouble()) return '${rate.toInt()}.0x';
  return '${rate}x';
}

IconData _modeIcon(PlayMode mode) => switch (mode) {
  PlayMode.sequential => Icons.playlist_play_rounded,
  PlayMode.listLoop => Icons.repeat_rounded,
  PlayMode.single => Icons.repeat_one_rounded,
  PlayMode.shuffle => Icons.shuffle_rounded,
};

/// 底部控制区：进度条、播放模式、上一首 / 播放暂停 / 下一首、播放列表都固定在底部；
/// 其余的倍速、定时关闭收在右上角「功能」按钮里，点击后横向展开到它左侧。
class _ControlCluster extends StatelessWidget {
  const _ControlCluster({
    super.key,
    this.compact = false,
    required this.expanded,
    required this.onToggle,
  });

  final bool compact;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final scale = compact ? 0.92 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 展开后功能按钮横向排在「功能」左侧空白处，紧贴着它。
            if (expanded) ...[
              const _FunctionPills(),
              const SizedBox(width: 8),
            ],
            _FunctionToggle(expanded: expanded, onTap: onToggle),
          ],
        ),
        const SizedBox(height: 6),
        SeekBar(
          position: player.position,
          duration: player.duration,
          onSeek: player.seek,
          showTime: true,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 播放模式：上一首左边的空白处，只显示图标。
            PlayerIconButton(
              icon: _modeIcon(player.mode),
              color: player.mode == PlayMode.sequential
                  ? AppColors.inkSoft
                  : AppColors.primary,
              onTap: () => _showPlayModeSheet(context),
              buttonSize: 46 * scale,
              iconSize: 24 * scale,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerIconButton(
                  icon: Icons.skip_previous_rounded,
                  enabled: player.hasPrevious,
                  onTap: player.previous,
                  buttonSize: 54 * scale,
                  iconSize: 30 * scale,
                ),
                const SizedBox(width: 18),
                PlayerPlayButton(
                  playing: player.playing,
                  onTap: player.toggle,
                  size: 70 * scale,
                ),
                const SizedBox(width: 18),
                PlayerIconButton(
                  icon: Icons.skip_next_rounded,
                  enabled: player.hasNext,
                  onTap: player.next,
                  buttonSize: 54 * scale,
                  iconSize: 30 * scale,
                ),
              ],
            ),
            // 播放列表：下一首右边的空白处，只显示图标。
            PlayerIconButton(
              icon: Icons.queue_music_rounded,
              onTap: () => _showQueueSheet(context),
              buttonSize: 46 * scale,
              iconSize: 24 * scale,
            ),
          ],
        ),
      ],
    );
  }
}

/// 展开的功能按钮：倍速 / 定时关闭，横向排在「功能」按钮左侧。
class _FunctionPills extends StatelessWidget {
  const _FunctionPills();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final remaining = player.sleepRemaining;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PillButton(
          icon: Icons.speed_rounded,
          label: '倍速 ${_rateLabel(player.rate)}',
          active: player.rate != 1.0,
          onTap: () => _showSpeedSheet(context),
        ),
        const SizedBox(width: 8),
        PillButton(
          icon: Icons.bedtime_rounded,
          label: remaining == null ? '定时关闭' : '剩 ${formatDuration(remaining)}',
          active: remaining != null,
          onTap: () => _showSleepSheet(context),
        ),
      ],
    );
  }
}

/// 右上角的小功能按钮：点击后横向展开 / 收起其余功能按钮。
class _FunctionToggle extends StatelessWidget {
  const _FunctionToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: expanded
                ? AppColors.primary.withValues(alpha: 0.24)
                : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: expanded
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                expanded ? Icons.close_rounded : Icons.tune_rounded,
                size: 15,
                color: expanded ? AppColors.primary : AppColors.inkSoft,
              ),
              const SizedBox(width: 5),
              Text(
                '功能',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: expanded ? AppColors.primary : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPlayModeSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          tint: AppColors.sheet,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '播放模式',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              ...PlayMode.values.map(
                (mode) => ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    _modeIcon(mode),
                    size: 20,
                    color: mode == player.mode
                        ? AppColors.primary
                        : AppColors.inkSoft,
                  ),
                  title: Text(
                    mode.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: mode == player.mode
                          ? AppColors.primary
                          : AppColors.ink,
                    ),
                  ),
                  trailing: mode == player.mode
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    player.setMode(mode);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showSleepSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          tint: AppColors.sheet,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: _DurationWheel(
            initial: player.sleepRemaining ?? const Duration(minutes: 30),
            active: player.sleepTimerActive,
            onConfirm: (duration) {
              player.startSleepTimer(duration);
              Navigator.of(sheetContext).pop();
            },
            onCancelTimer: () {
              player.cancelSleepTimer();
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      ),
    ),
  );
}

/// 定时关闭选择器：时 : 分 : 秒 三列滚轮，随便选多久都行。
class _DurationWheel extends StatefulWidget {
  const _DurationWheel({
    required this.initial,
    required this.active,
    required this.onConfirm,
    required this.onCancelTimer,
  });

  final Duration initial;
  final bool active;
  final ValueChanged<Duration> onConfirm;
  final VoidCallback onCancelTimer;

  @override
  State<_DurationWheel> createState() => _DurationWheelState();
}

class _DurationWheelState extends State<_DurationWheel> {
  static const int _hourCount = 24;
  static const int _minuteCount = 60;
  static const int _secondCount = 60;

  late int _hours = widget.initial.inHours.clamp(0, _hourCount - 1);
  late int _minutes = (widget.initial.inMinutes % 60).clamp(
    0,
    _minuteCount - 1,
  );
  late int _seconds = (widget.initial.inSeconds % 60).clamp(
    0,
    _secondCount - 1,
  );

  late final FixedExtentScrollController _hourController =
      FixedExtentScrollController(initialItem: _hours);
  late final FixedExtentScrollController _minuteController =
      FixedExtentScrollController(initialItem: _minutes);
  late final FixedExtentScrollController _secondController =
      FixedExtentScrollController(initialItem: _seconds);

  Duration get _duration =>
      Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '定时关闭',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '滚动选择小时 / 分钟 / 秒',
          style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _column(
                '时',
                _hourCount,
                _hourController,
                (v) => setState(() => _hours = v),
              ),
            ),
            Expanded(
              child: _column(
                '分',
                _minuteCount,
                _minuteController,
                (v) => setState(() => _minutes = v),
              ),
            ),
            Expanded(
              child: _column(
                '秒',
                _secondCount,
                _secondController,
                (v) => setState(() => _seconds = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: _duration == Duration.zero
                  ? null
                  : () => widget.onConfirm(_duration),
              child: const Text('开始'),
            ),
            const Spacer(),
            if (widget.active)
              TextButton(
                onPressed: widget.onCancelTimer,
                child: const Text('取消定时'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _column(
    String unit,
    int count,
    FixedExtentScrollController controller,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 38,
            useMagnifier: true,
            magnification: 1.08,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
              background: AppColors.primary.withValues(alpha: 0.14),
              capStartEdge: false,
              capEndEdge: false,
            ),
            onSelectedItemChanged: onChanged,
            children: [
              for (var i = 0; i < count; i++)
                Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

void _showSpeedSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          tint: AppColors.sheet,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '播放倍速',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              ...PlayerService.speedOptions.map(
                (option) => ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: Text(
                    _rateLabel(option),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: option == player.rate
                          ? AppColors.primary
                          : AppColors.ink,
                    ),
                  ),
                  trailing: option == player.rate
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    player.setRate(option);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showQueueSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          tint: AppColors.sheet,
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '播放列表',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: player.queue.length,
                  itemBuilder: (context, index) {
                    final item = player.queue[index];
                    final active = index == player.index;
                    return MediaTile(
                      item: item,
                      active: active,
                      playing: active && player.playing,
                      onTap: () {
                        player.playQueue(player.queue, index);
                        Navigator.of(sheetContext).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
