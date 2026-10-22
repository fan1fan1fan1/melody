import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../services/player_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/mini_player.dart';
import 'media_library_view.dart';
import 'noise_page.dart';
import 'settings_page.dart';

/// 应用骨架：底部导航 + 迷你播放条。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final GlobalKey<MediaLibraryViewState> _audioKey =
      GlobalKey<MediaLibraryViewState>();
  final GlobalKey<MediaLibraryViewState> _videoKey =
      GlobalKey<MediaLibraryViewState>();

  PlayerService? _player;

  @override
  void initState() {
    super.initState();
    final player = context.read<PlayerService>();
    _player = player;
    player.addListener(_syncWidget);
    WidgetService.listen(player);
    WidgetService.requestedTab.addListener(_openRequestedTab);
    WidgetService.pushMini(player);
  }

  @override
  void dispose() {
    _player?.removeListener(_syncWidget);
    WidgetService.requestedTab.removeListener(_openRequestedTab);
    super.dispose();
  }

  /// 播放状态一变就同步给桌面组件（内部会过滤掉没有变化的情况）。
  void _syncWidget() {
    final player = _player;
    if (player != null) WidgetService.pushMini(player);
  }

  /// 桌面组件点了白噪音按钮：切到白噪音页。
  void _openRequestedTab() {
    final tab = WidgetService.requestedTab.value;
    if (tab == null || !mounted) return;
    WidgetService.requestedTab.value = null;
    setState(() => _index = tab);
  }

  /// 手机端按返回键：先退文件夹，再问一次是否退出软件。
  Future<void> _handleBack() async {
    final view = _index == 0
        ? _audioKey.currentState
        : (_index == 1 ? _videoKey.currentState : null);
    if (view != null && view.handleSystemBack()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出 Melody'),
        content: const Text('确定要退出软件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 手机端拦截返回键，先提示再退出；其它平台保持默认行为。
      canPop: !Platform.isAndroid,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !Platform.isAndroid) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07060D),
        body: IndexedStack(
          index: _index,
          children: [
            MediaLibraryView(key: _audioKey, kind: MediaKind.audio),
            MediaLibraryView(key: _videoKey, kind: MediaKind.video),
            const NoisePage(),
            const SettingsPage(),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            _BottomNav(
              index: _index,
              onChanged: (value) => setState(() => _index = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const List<(IconData, String, Color)> _items = [
    (Icons.library_music_rounded, '音乐', AppColors.primary),
    (Icons.movie_rounded, '视频', AppColors.videoAccent),
    (Icons.spa_rounded, '白噪音', AppColors.noise),
    (Icons.settings_rounded, '设置', Color(0xFFCFC9E4)),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      tint: AppColors.glass,
      blur: 26,
      border: const Border(top: BorderSide(color: Color(0x1FFFFFFF))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    accent: _items[i].$3,
                    active: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : AppColors.inkSoft;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
