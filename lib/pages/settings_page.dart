import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import 'artists_page.dart';
import 'history_page.dart';
import 'organize_page.dart';
import 'rankings_page.dart';
import 'sound_page.dart';

/// 设置页：工具（整理 / 按作者 / 声音效果）、关于（常见问题 / 检查更新 / 反馈 / 作者 / 版本）。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const String appName = 'Melody';
  static const String version = '1.0.0';
  static const String email = '2282090729@qq.com';

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('设置')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
          children: [
            _buildBrandCard(),
            const SizedBox(height: 22),
            const _SectionLabel('工具'),
            const SizedBox(height: 10),
            _card(
              children: [
                _ActionTile(
                  icon: Icons.auto_awesome_motion_rounded,
                  title: '整理',
                  subtitle: '提取歌名与作者为txt文本',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OrganizePage(),
                    ),
                  ),
                ),
                _ActionTile(
                  icon: Icons.groups_rounded,
                  title: '按作者',
                  subtitle: '同作者汇总查看',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ArtistsPage(),
                    ),
                  ),
                ),
                _divider(),
                _ActionTile(
                  icon: Icons.history_rounded,
                  title: '历史播放记录',
                  subtitle: '每天 0 点重置',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryPage(),
                    ),
                  ),
                ),
                _divider(),
                _ActionTile(
                  icon: Icons.leaderboard_rounded,
                  title: '榜单',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RankingsPage(),
                    ),
                  ),
                ),
                _divider(),
                _ActionTile(
                  icon: Icons.graphic_eq_rounded,
                  title: '声音效果',
                  subtitle: '调节播放音量',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SoundPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('关于'),
            const SizedBox(height: 10),
            _card(
              children: [
                _ActionTile(
                  icon: Icons.help_outline_rounded,
                  title: '常见问题',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const _FaqPage()),
                  ),
                ),
                _divider(),
                _ActionTile(
                  icon: Icons.refresh_rounded,
                  title: '检查更新',
                  subtitle: '当前版本 $version',
                  onTap: () => _showUpdateDialog(context),
                ),
                _divider(),
                _ActionTile(
                  icon: Icons.mail_outline_rounded,
                  title: '反馈',
                  subtitle: '复制作者邮箱',
                  onTap: () => _showFeedbackDialog(context),
                ),
                _divider(),
                _ActionTile(
                  icon: Icons.alternate_email_rounded,
                  title: '作者',
                  subtitle: email,
                  trailing: null,
                  onTap: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: children),
      ),
    );
  }

  static Widget _divider() =>
      const Divider(height: 1, indent: 18, endIndent: 18);

  /// 顶部品牌卡：只放图标与软件名，不写版本。
  Widget _buildBrandCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x26FFFFFF), Color(0x12FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('1.jpg', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            appName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '本地音乐与视频播放器',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  void _copyEmail(BuildContext pageContext, BuildContext dialogContext) {
    Clipboard.setData(const ClipboardData(text: email));
    Navigator.of(dialogContext).pop();
    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('邮箱已复制：$email'),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('反馈'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '遇到问题或者有好的建议，欢迎发送到作者邮箱：',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '复制邮箱',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    color: AppColors.primary,
                    onPressed: () => _copyEmail(context, dialogContext),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () => _copyEmail(context, dialogContext),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('复制邮箱'),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('检查更新'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前版本 $version',
              style: TextStyle(fontSize: 13, color: AppColors.ink),
            ),
            SizedBox(height: 8),
            Text(
              '已是最新版本，感谢你的使用！',
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }
}

/// 常见问题页面。
class _FaqPage extends StatelessWidget {
  const _FaqPage();

  static const List<(String, String)> _faqs = [
    (
      '如何导入音乐或视频？',
      '导入的每个文件夹都会在「音乐」或「视频」页显示成一张光碟。点击右上角「+」，在弹出的窗口里选择「导入文件」「导入文件夹」或「扫描本机」。已经导入过的文件会自动跳过，不会重复导入。',
    ),
    (
      '支持哪些格式？',
      '音乐支持 mp3、m4a、aac、flac、wav、ogg、wma 等；视频支持 mp4、mov、mkv、avi、webm、flv 等常见格式。',
    ),
    (
      '「全部文件」和「喜欢」是什么？',
      '这两个是软件内置的默认文件夹：①「全部文件」汇总当前类型下的所有文件；②「喜欢」汇总你点过爱心的文件。它们带有「默认」标签，和其它文件夹样式略有区别，不能改名、删除或拖动。',
    ),
    (
      '怎么搜索歌曲或视频？',
      '在「音乐」或「视频」页顶部的搜索框输入关键词，可同时匹配文件夹名、歌曲名、作者名（视频为文件夹名、视频名）。搜索结果会自动去重：同一首歌即使出现在多个文件夹里也只会显示一条，并标注「来自文件夹」列出它所在的位置。',
    ),
    (
      '怎么调整歌曲顺序？',
      '轻触光碟进入文件夹后，点击右上角「排序」可在「A-Z」「作者 A-Z」「手动」之间切换；选择「手动」后会进入新页面，拖动右侧手柄即可自定义顺序，顺序会自动记住。',
    ),
    ('怎么整理文件夹？', '在首页长按文件夹（电脑端右键），可以置顶、改名、拖动调整顺序，或者从列表里删除（不会删除磁盘上的原文件）。也可以新建自建文件夹，把歌曲归到里面。'),
    (
      '怎么修改歌曲名或作者名？',
      '在歌曲列表里长按某首歌（或点右侧「更多」），选择「修改歌曲名 / 作者名」即可单独修改；同一首歌还可以「移动到文件夹」或「复制到文件夹」来重新归类。',
    ),
    ('怎么把歌曲加到播放列表？', '在歌曲列表里点右侧「更多」，选择「添加到播放列表」，这首歌就会排到当前播放列表的最后。'),
    (
      '播放是连续的吗？',
      '是的。播放完当前文件会自动播放列表中的下一首。左下角图标可切换播放模式：顺序播放、列表循环、单曲循环、随机播放；也支持上一首 / 下一首。',
    ),
    (
      '定时关闭怎么用？',
      '在播放详情页点击进度条上方右侧的「功能」按钮，展开后选择「定时关闭」，用滚轮选择小时 / 分钟 / 秒，时间到会自动暂停播放；也可以随时取消。',
    ),
    (
      '怎么调节播放倍速？',
      '在播放详情页点击「功能」，选择「倍速」，支持 0.5x 到 2.0x 六档，音频和视频都适用。',
    ),
    (
      '声音效果怎么调？',
      '在「设置 → 声音效果」里拖动滑块调节音量（0–130，100 为标准，超过即增强），也可以一键选择轻柔 / 标准 / 响亮 / 增强。调好的音量会自动记住。',
    ),
    (
      '「按作者」怎么用？',
      '在「设置 → 按作者」里可切换音频 / 视频，把同一作者的文件汇总查看；顶部搜索框可按作者名搜索。点右上角「管理作者」可新增、改名、合并、删除作者，或拖动调整顺序；还可以导出作者汇总 txt。',
    ),
    (
      '怎么导出歌曲信息？',
      '在「设置 → 整理」里可以筛选音频 / 视频、勾选文件夹、选择整理样式，然后把「歌曲名 + 作者」导出成 txt 文本。',
    ),
    (
      '历史播放记录是什么？',
      '在「设置 → 历史播放记录」里显示当天播放过的内容，按最近播放排序；每天 0 点会自动清空，只保留当天的记录。',
    ),
    (
      '榜单是什么？',
      '在「设置 → 榜单」里查看「播放歌曲排行」和「播放作者排行」，按播放次数实时更新，各显示前十名。',
    ),
    (
      '白噪音怎么用？',
      '白噪音页内置了下雨、海浪、森林、篝火等声音，适合助眠或专注。目前这些声音还在准备中，点击会提示音频还没导入。',
    ),
    (
      '桌面组件怎么用？',
      '长按桌面添加「Melody 正在播放」组件，会显示成一行：左边是正在播放的光盘、中间是歌名和作者、右边是上一首 / 暂停播放 / 下一首，音频和视频通用，可直接在桌面切歌。',
    ),
    ('会修改或删除我的文件吗？', '不会。Melody 只是读取并播放你导入的文件，不会移动、修改或删除磁盘上的原文件；整理、改名、删除等操作只影响软件内的显示。'),
    ('提示文件无法播放怎么办？', '多半是文件被移动或删除了，重新导入一次即可；也可能是格式比较特殊，暂时不被支持。'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('常见问题')),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
          itemCount: _faqs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) => Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _faqs[index].$1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _faqs[index].$2,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.65,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片区块标题。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// 设置项。[onTap] 为空时表示纯展示，不可点击。
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.onTap,
    this.subtitle,
    this.trailing = Icons.chevron_right_rounded,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Icon(trailing, size: 20, color: AppColors.inkSoft),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
