import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../theme/app_theme.dart';
import 'media_artwork.dart';

/// 文件列表中的一行。
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.active,
    required this.playing,
    required this.onTap,
    this.onRemove,
    this.onAddToQueue,
    this.onEdit,
    this.onMove,
    this.onToggleFavorite,
    this.favorite = false,
    this.menuEnabled = true,
    this.onCopy,
    this.footnote,
  });

  final MediaItem item;
  final bool active;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  /// 标题下方额外的一行小字（例如「来自文件夹」）。
  final String? footnote;

  /// 「添加到播放列表」的回调。
  final VoidCallback? onAddToQueue;

  /// 长按或菜单里修改歌曲名 / 作者名的回调。
  final VoidCallback? onEdit;

  /// 「移动到文件夹」的回调。
  final VoidCallback? onMove;

  /// 「复制到文件夹」的回调。
  final VoidCallback? onCopy;

  /// 点小心心：加入 / 取消「喜欢」。
  final VoidCallback? onToggleFavorite;

  /// 是否已经被标记为喜欢。
  final bool favorite;

  /// 是否显示右侧的「更多」菜单。
  final bool menuEnabled;

  @override
  Widget build(BuildContext context) {
    final artist = item.artist;
    final hasMenu =
        onRemove != null ||
        onAddToQueue != null ||
        onEdit != null ||
        onMove != null ||
        onCopy != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              MediaArtwork(
                kind: item.kind,
                size: 46,
                radius: 12,
                glow: active,
                artworkPath: item.artworkPath,
                seed: item.path,
                label: item.coverInitial,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: active ? AppColors.primary : AppColors.ink,
                      ),
                    ),
                    if (artist != null && artist.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                    if (footnote != null && footnote!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        footnote!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onToggleFavorite != null)
                IconButton(
                  tooltip: favorite ? '取消喜欢' : '喜欢',
                  onPressed: onToggleFavorite,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  icon: Icon(
                    favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 19,
                    color: favorite ? AppColors.primary : AppColors.inkSoft,
                  ),
                ),
              if (active && playing)
                const _EqualizerIcon()
              else
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: AppColors.inkSoft,
                  size: 24,
                ),
              if (menuEnabled && hasMenu)
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: AppColors.inkSoft,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'queue') onAddToQueue?.call();
                    if (value == 'favorite') onToggleFavorite?.call();
                    if (value == 'edit') onEdit?.call();
                    if (value == 'move') onMove?.call();
                    if (value == 'copy') onCopy?.call();
                    if (value == 'remove') onRemove?.call();
                  },
                  itemBuilder: (context) => [
                    if (onToggleFavorite != null)
                      PopupMenuItem<String>(
                        value: 'favorite',
                        child: Text(favorite ? '取消喜欢' : '喜欢'),
                      ),
                    if (onAddToQueue != null)
                      const PopupMenuItem<String>(
                        value: 'queue',
                        child: Text('添加到播放列表'),
                      ),
                    if (onEdit != null)
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('修改歌曲名 / 作者名'),
                      ),
                    if (onMove != null)
                      const PopupMenuItem<String>(
                        value: 'move',
                        child: Text('移动到文件夹'),
                      ),
                    if (onCopy != null)
                      const PopupMenuItem<String>(
                        value: 'copy',
                        child: Text('复制到文件夹'),
                      ),
                    if (onRemove != null)
                      const PopupMenuItem<String>(
                        value: 'remove',
                        child: Text('从列表移除'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 正在播放时的跳动音符图标。
class _EqualizerIcon extends StatelessWidget {
  const _EqualizerIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.graphic_eq_rounded,
      color: AppColors.primary,
      size: 24,
    );
  }
}
