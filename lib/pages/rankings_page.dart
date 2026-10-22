import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/play_stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

/// 榜单：顶部「歌曲 / 作者」两个标签切换，各显示播放次数前十，实时更新。
class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  /// 0 = 歌曲，1 = 作者。
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<PlayStatsService>();
    final songs = stats.topSongs;
    final artists = stats.topArtists;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('榜单')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
          children: [
            Row(
              children: [
                Expanded(
                  child: _RankTab(
                    label: '歌曲',
                    icon: Icons.music_note_rounded,
                    selected: _tab == 0,
                    accent: AppColors.primary,
                    onTap: () => setState(() => _tab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RankTab(
                    label: '作者',
                    icon: Icons.person_rounded,
                    selected: _tab == 1,
                    accent: AppColors.videoAccent,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _tab == 0
                  ? '播放歌曲排行 前十'
                  : '播放作者排行 前十',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            if (_tab == 0)
              if (songs.isEmpty)
                const _EmptyList()
              else
                _RankCard(
                  children: [
                    for (var i = 0; i < songs.length; i++)
                      _RankRow(
                        rank: i + 1,
                        title: songs[i].title,
                        count: songs[i].count,
                        accent: AppColors.primary,
                      ),
                  ],
                )
            else if (artists.isEmpty)
              const _EmptyList()
            else
              _RankCard(
                children: [
                  for (var i = 0; i < artists.length; i++)
                    _RankRow(
                      rank: i + 1,
                      title: artists[i].name,
                      count: artists[i].count,
                      accent: AppColors.videoAccent,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 顶部「歌曲 / 作者」切换标签。
class _RankTab extends StatelessWidget {
  const _RankTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.2) : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : AppColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? accent : AppColors.inkSoft,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(children: children),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.title,
    required this.count,
    required this.accent,
  });

  final int rank;
  final String title;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final top = rank <= 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: top ? accent.withValues(alpha: 0.22) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: top ? accent : AppColors.inkSoft,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count 次',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          '还没有播放记录',
          style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
        ),
      ),
    );
  }
}
