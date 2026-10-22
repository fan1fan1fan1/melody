import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../pages/now_playing_page.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';
import 'media_artwork.dart';
import 'player_controls.dart';
import 'seek_bar.dart';

/// 底部迷你播放条：左侧信息、中间进度、右侧控制，点击进入播放详情页。
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final item = player.current;
    if (item == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: GlassPanel(
        borderRadius: BorderRadius.circular(20),
        tint: AppColors.glass,
        border: Border.all(color: AppColors.cardBorder),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => openNowPlaying(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 520;
                  final info = _MiniInfo(item: item);
                  final controls = _MiniControls(player: player);
                  if (!wide) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(child: info),
                            controls,
                          ],
                        ),
                        const SizedBox(height: 2),
                        SeekBar(
                          position: player.position,
                          duration: player.duration,
                          compact: true,
                          onSeek: player.seek,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 4, child: info),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 5,
                        child: SeekBar(
                          position: player.position,
                          duration: player.duration,
                          compact: true,
                          onSeek: player.seek,
                        ),
                      ),
                      const SizedBox(width: 14),
                      controls,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MediaArtwork(
          kind: item.kind,
          size: 40,
          radius: 11,
          artworkPath: item.artworkPath,
          seed: item.path,
          label: item.coverInitial,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.artist ?? '未知作者',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniControls extends StatelessWidget {
  const _MiniControls({required this.player});

  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerIconButton(
          icon: Icons.skip_previous_rounded,
          enabled: player.hasPrevious,
          onTap: player.previous,
        ),
        PlayerPlayButton(
          playing: player.playing,
          onTap: player.toggle,
          size: 40,
        ),
        PlayerIconButton(
          icon: Icons.skip_next_rounded,
          enabled: player.hasNext,
          onTap: player.next,
        ),
      ],
    );
  }
}
