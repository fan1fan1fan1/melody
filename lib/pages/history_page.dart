import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../services/play_stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/media_artwork.dart';

/// 历史播放记录：只显示当天播放过的内容，每天 0 点后自动清空。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  static String _timeLabel(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  String get _keyword => _query.trim().toLowerCase();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<PlayStatsService>();
    final history = stats.history;
    final filtered = _keyword.isEmpty
        ? history
        : history
              .where(
                (e) =>
                    e.title.toLowerCase().contains(_keyword) ||
                    (e.artist ?? '').toLowerCase().contains(_keyword),
              )
              .toList();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('历史播放记录')),
        body: Column(
          children: [
            _HistorySearchBar(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
            Expanded(
              child: history.isEmpty
                  ? const _EmptyHint()
                  : filtered.isEmpty
                  ? const _NoResult()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(6, 0, 2, 4),
                            child: Text(
                              '今天 共 ${filtered.length} 条',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          );
                        }
                        final entry = filtered[index - 1];
                        return _HistoryRow(entry: entry);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 历史页顶部的搜索框。
class _HistorySearchBar extends StatelessWidget {
  const _HistorySearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 19,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
                cursorColor: AppColors.primary,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '输入关键字查询',
                  hintStyle: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClear,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 52,
            color: AppColors.inkSoft,
          ),
          SizedBox(height: 12),
          Text(
            '今天还没有播放记录',
            style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
          SizedBox(height: 6),
          Text(
            '播放过的音乐会显示在这里，每天 0 点自动清空',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _NoResult extends StatelessWidget {
  const _NoResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '没有匹配的记录',
        style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final PlayHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final artist = entry.artist;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          MediaArtwork(
            kind: entry.kind,
            size: 46,
            radius: 12,
            icon: entry.kind == MediaKind.audio
                ? Icons.music_note_rounded
                : Icons.movie_creation_rounded,
            seed: entry.path,
            label: entry.title.isEmpty ? '♪' : entry.title.substring(0, 1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (artist != null && artist.isNotEmpty) ...[
                  const SizedBox(height: 3),
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            HistoryPage._timeLabel(entry.playedAt),
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
