import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_panel.dart';
import '../widgets/media_artwork.dart';
import '../widgets/media_tile.dart';
import 'now_playing_page.dart';

/// 按作者：把每个作者保存过的文件汇总成一个文件夹的样子。
class ArtistsPage extends StatefulWidget {
  const ArtistsPage({super.key});

  /// 没有识别出作者时，统一归到这一组。
  static const String unknownArtist = '未知作者';

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  MediaKind _kind = MediaKind.audio;
  bool _busy = false;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  String get _keyword => _query.trim().toLowerCase();

  Color get _accent =>
      _kind == MediaKind.audio ? AppColors.primary : AppColors.videoAccent;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 作者分组：key 为作者名小写（不区分大小写地归并同一人）。
  Map<String, _ArtistGroup> _groupByArtist(LibraryService library) =>
      _groupArtists(library, _kind);

  /// 作者分组的显示顺序：先按用户拖动过的顺序，其余按名称排。
  List<String> _orderedKeys(
    Map<String, _ArtistGroup> grouped,
    LibraryService library,
  ) => _orderedArtistKeys(grouped, library, _kind);

  /// 把每个作者的歌曲汇总导出成 txt。
  Future<void> _export(Map<String, _ArtistGroup> grouped) async {
    if (grouped.isEmpty || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    // 名称相同的作者已经被归并，这里只保留有文件的作者。
    final groups =
        grouped.values.where((group) => group.items.isNotEmpty).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    if (groups.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final buffer = StringBuffer()
      ..writeln(_kind == MediaKind.audio ? '音乐 按作者' : '视频 按作者')
      ..writeln('作者 ${groups.length} 位')
      ..writeln();
    for (final group in groups) {
      buffer.writeln('【${group.name}】共 ${group.items.length} 首');
      for (final item in group.items) {
        buffer.writeln('  - ${item.title}');
      }
      buffer.writeln();
    }
    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final fileName = _kind == MediaKind.audio ? '作者汇总.txt' : '作者汇总-视频.txt';
    try {
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/plain',
        dialogTitle: '导出作者汇总',
      );
      if (uri == null) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('已导出 ${groups.length} 位作者到 ${uri.path}'),
        ),
      );
    } catch (error) {
      // 部分平台不支持另存对话框，退回到应用文档目录。
      try {
        final base = await getApplicationDocumentsDirectory();
        final file = File('${base.path}${Platform.pathSeparator}$fileName');
        await file.writeAsBytes(bytes);
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('已导出到 ${file.path}'),
          ),
        );
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('导出失败：$error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final grouped = _groupByArtist(library);
    final keyword = _keyword;
    final artists = _orderedKeys(grouped, library)
        .where(
          (key) =>
              keyword.isEmpty ||
              grouped[key]!.name.toLowerCase().contains(keyword),
        )
        .toList();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('按作者'),
          actions: [
            IconButton(
              tooltip: '管理作者',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _ManageArtistsPage(initialKind: _kind),
                ),
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: '导出作者汇总',
              onPressed: artists.isEmpty ? null : () => _export(grouped),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
          children: [
            Row(
              children: [
                _ChoiceChip(
                  label: '音频',
                  icon: Icons.library_music_rounded,
                  selected: _kind == MediaKind.audio,
                  accent: AppColors.primary,
                  onTap: () => setState(() => _kind = MediaKind.audio),
                ),
                const SizedBox(width: 10),
                _ChoiceChip(
                  label: '视频',
                  icon: Icons.movie_rounded,
                  selected: _kind == MediaKind.video,
                  accent: AppColors.videoAccent,
                  onTap: () => setState(() => _kind = MediaKind.video),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AuthorSearchBar(
              controller: _searchController,
              accent: _accent,
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: 14),
            Text(
              keyword.isEmpty
                  ? '共 ${artists.length} 位作者 ${grouped.values.fold<int>(0, (sum, group) => sum + group.items.length)} 个文件'
                  : '匹配 ${artists.length} 位作者',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            if (artists.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    keyword.isEmpty ? '还没有导入任何文件' : '没有找到匹配的作者',
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              for (final artist in artists)
                _ArtistRow(
                  name: grouped[artist]!.name,
                  kind: _kind,
                  items: grouped[artist]!.items,
                  accent: _accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _ArtistSongsPage(
                        artist: grouped[artist]!.name,
                        items: grouped[artist]!.items,
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

/// 按作者页顶部的搜索框。
class _AuthorSearchBar extends StatelessWidget {
  const _AuthorSearchBar({
    required this.controller,
    required this.accent,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final Color accent;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
              cursorColor: accent,
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
    );
  }
}

/// 一位作者的分组：作者名（不区分大小写归并同一人）+ 该作者的全部文件。
class _ArtistGroup {
  _ArtistGroup(this.name);

  /// 展示用作者名：取该作者出现次数最多的那种写法。
  String name;

  final List<MediaItem> items = <MediaItem>[];

  /// 各种大小写写法的出现次数，用于挑选展示名。
  final Map<String, int> spellings = <String, int>{};

  /// 出现最多的写法的次数。
  int bestCount = 0;

  /// 这一组是「没有识别出作者」的那一组。
  bool get isUnknown => name == ArtistsPage.unknownArtist;
}

/// 作者分组：key 为作者名小写（不区分大小写地把同一人归并到一起）。
/// 手动新增但还没有文件的作者也会出现在结果里（items 为空）。
Map<String, _ArtistGroup> _groupArtists(
  LibraryService library,
  MediaKind kind,
) {
  final grouped = <String, _ArtistGroup>{};
  for (final item in library.items(kind)) {
    final artist = item.artist?.trim();
    final name = (artist == null || artist.isEmpty)
        ? ArtistsPage.unknownArtist
        : artist;
    final group = grouped.putIfAbsent(
      name.toLowerCase(),
      () => _ArtistGroup(name),
    );
    group.items.add(item);
    group.spellings.update(name, (count) => count + 1, ifAbsent: () => 1);
  }
  // 同一位作者可能有多种大小写写法，展示出现最多的那种。
  for (final group in grouped.values) {
    var best = group.name;
    var bestCount = 0;
    group.spellings.forEach((spelling, count) {
      if (count > bestCount) {
        best = spelling;
        bestCount = count;
      }
    });
    group.name = best;
    group.bestCount = bestCount;
    group.items.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
  }
  // 手动新增的作者文件夹即使还没有文件也要显示。
  for (final name in library.customArtists(kind)) {
    final group = grouped.putIfAbsent(
      name.toLowerCase(),
      () => _ArtistGroup(name),
    );
    if (group.spellings.isEmpty) group.name = name;
  }
  // 已删除的作者不再出现。
  final hidden = library
      .hiddenArtists(kind)
      .map((name) => name.toLowerCase())
      .toSet();
  grouped.removeWhere((key, _) => hidden.contains(key));
  return grouped;
}

/// 作者分组的显示顺序：先按用户拖动过的顺序，其余按名称排。
List<String> _orderedArtistKeys(
  Map<String, _ArtistGroup> grouped,
  LibraryService library,
  MediaKind kind,
) {
  final order = library.artistOrder(kind);
  return grouped.keys.toList()..sort((a, b) {
    final indexA = order.indexOf(a);
    final indexB = order.indexOf(b);
    if (indexA >= 0 && indexB >= 0) return indexA - indexB;
    if (indexA >= 0) return -1;
    if (indexB >= 0) return 1;
    return a.compareTo(b);
  });
}

/// 当前类型下全部作者的展示名，用于「合并到已有作者」的快捷选项。
List<String> _knownArtistNames(LibraryService library, MediaKind kind) {
  final grouped = _groupArtists(library, kind);
  return [
    for (final key in _orderedArtistKeys(grouped, library, kind))
      grouped[key]!.name,
  ];
}

/// 弹出输入作者名的对话框。
/// 返回 null 表示取消；返回空字符串表示恢复成文件自带的作者信息。
Future<String?> _promptArtistName(
  BuildContext context, {
  required String title,
  required String message,
  required String initial,
  required List<String> known,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '输入作者名',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) =>
                  Navigator.of(dialogContext).pop(value.trim()),
            ),
            if (known.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                '已有作者（点一下合并过去）',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in known)
                    ActionChip(
                      label: Text(name),
                      onPressed: () => Navigator.of(dialogContext).pop(name),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(''),
          child: const Text('恢复默认'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// 一行一位作者，样式和首页的文件夹一致。
class _ArtistRow extends StatelessWidget {
  const _ArtistRow({
    required this.name,
    required this.kind,
    required this.items,
    required this.accent,
    required this.onTap,
  });

  final String name;
  final MediaKind kind;
  final List<MediaItem> items;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = items.isEmpty ? null : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: GlassPanel(
            borderRadius: BorderRadius.circular(20),
            tint: AppColors.card,
            blur: 16,
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                MediaArtwork(
                  kind: kind,
                  size: 52,
                  radius: 14,
                  artworkPath: first?.artworkPath,
                  seed: name,
                  label: name.isEmpty ? '?' : name.substring(0, 1),
                  glow: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        first == null
                            ? '暂无文件'
                            : '${items.length} ${kind == MediaKind.audio ? '首' : '个'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: accent, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 某位作者的全部文件，可以直接播放；从「管理作者」进来时还能改作者。
class _ArtistSongsPage extends StatelessWidget {
  const _ArtistSongsPage({
    required this.artist,
    required this.items,
    this.manageKind,
    this.artistKey,
  });

  final String artist;
  final List<MediaItem> items;

  /// 非空表示这是管理流程里的详情页：可以批量改作者名。
  final MediaKind? manageKind;

  /// 管理流程里这一组的键（作者名小写）。
  final String? artistKey;

  bool get _editable => manageKind != null;

  /// 把这位作者名下的全部文件统一改成新的作者名。
  Future<void> _renameAll(
    BuildContext context,
    List<MediaItem> list,
    String current,
  ) async {
    final kind = manageKind!;
    final library = context.read<LibraryService>();
    final known = _knownArtistNames(library, kind)
      ..removeWhere((name) => name.toLowerCase() == current.toLowerCase());
    final result = await _promptArtistName(
      context,
      title: '修改作者名',
      message: '会把「$current」名下 ${list.length} 个文件的作者一起改掉；填一个已有的作者名就是合并过去。',
      initial: current == ArtistsPage.unknownArtist ? '' : current,
      known: known,
    );
    if (result == null || list.isEmpty || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final changed = await library.renameArtist(
      kind,
      from: current,
      items: list,
      to: result,
    );
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          changed == 0
              ? '没有需要修改的文件'
              : '已把 $changed 个文件归到「${result.isEmpty ? '文件自带的作者' : result}」',
        ),
      ),
    );
  }

  /// 只改这一首的作者。
  Future<void> _editOne(
    BuildContext context,
    MediaItem item,
    List<String> known,
  ) async {
    final library = context.read<LibraryService>();
    final result = await _promptArtistName(
      context,
      title: '所属作者',
      message: '「${item.title}」这一首的作者，改完只影响它自己。',
      initial: item.customArtist ?? item.artist ?? '',
      known: known,
    );
    if (result == null) return;
    await library.setItemArtist(item, result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();
    final kind = manageKind;
    var list = items;
    var name = artist;
    if (kind != null) {
      final group = _groupArtists(library, kind)[artistKey];
      if (group != null) {
        list = group.items;
        name = group.name;
      }
    }
    final known = kind == null
        ? const <String>[]
        : (_knownArtistNames(library, kind)
            ..removeWhere((each) => each.toLowerCase() == name.toLowerCase()));
    final first = list.isEmpty ? null : list.first;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(name),
          actions: [
            if (_editable)
              IconButton(
                tooltip: '修改作者名',
                onPressed: list.isEmpty
                    ? null
                    : () => _renameAll(context, list, name),
                icon: const Icon(Icons.drive_file_rename_outline_rounded),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
          children: [
            if (_editable)
              GlassPanel(
                borderRadius: BorderRadius.circular(20),
                tint: AppColors.card,
                blur: 16,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MediaArtwork(
                          kind: kind!,
                          size: 52,
                          radius: 14,
                          artworkPath: first?.artworkPath,
                          seed: name,
                          label: name.isEmpty ? '?' : name.substring(0, 1),
                          glow: true,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${list.length} 个文件',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: list.isEmpty
                          ? null
                          : () => _renameAll(context, list, name),
                      icon: const Icon(
                        Icons.drive_file_rename_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('修改作者名（名下全部文件一起改）'),
                    ),
                  ],
                ),
              )
            else
              Text(
                '共 ${list.length} 个文件',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            const SizedBox(height: 8),
            for (final item in list)
              MediaTile(
                item: item,
                active: player.current?.path == item.path,
                playing: player.playing && player.current?.path == item.path,
                favorite: item.favorite,
                onTap: () {
                  player.playItem(list, item);
                  if (item.kind == MediaKind.video) openNowPlaying(context);
                },
                onEdit: _editable ? () => _editOne(context, item, known) : null,
                onToggleFavorite: () => library.toggleFavorite(item),
                onAddToQueue: () =>
                    context.read<PlayerService>().addToQueue(<MediaItem>[item]),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? accent : AppColors.inkSoft,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
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

/// 管理作者：新增作者文件夹，或调整每个文件所属的作者。
class _ManageArtistsPage extends StatefulWidget {
  const _ManageArtistsPage({required this.initialKind});

  final MediaKind initialKind;

  @override
  State<_ManageArtistsPage> createState() => _ManageArtistsPageState();
}

class _ManageArtistsPageState extends State<_ManageArtistsPage> {
  late MediaKind _kind = widget.initialKind;
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _accent =>
      _kind == MediaKind.audio ? AppColors.primary : AppColors.videoAccent;

  /// 拖动调整作者文件夹的顺序。
  Future<void> _reorder(
    LibraryService library,
    int oldIndex,
    int newIndex,
    List<String> current,
  ) async {
    final list = List<String>.of(current);
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), moved);
    await library.reorderArtists(_kind, list);
  }

  /// 删除某位作者：不再显示该作者的文件夹。
  Future<void> _hide(LibraryService library, _ArtistGroup group) async {
    await library.hideArtist(_kind, group.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('已删除作者「${group.name}」，可在页面底部恢复'),
      ),
    );
  }

  Future<void> _create(LibraryService library) async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('先输入作者名再点新增'),
        ),
      );
      return;
    }
    await library.addCustomArtist(_kind, name);
    _controller.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('已新增作者「$name」'),
      ),
    );
  }

  /// 把一位作者名下的全部文件统一改成新的作者名。
  /// 自动识别错了就改这里；填一个已有的作者名即合并过去。
  Future<void> _rename(LibraryService library, _ArtistGroup group) async {
    final known = _knownArtistNames(library, _kind)
      ..removeWhere((name) => name.toLowerCase() == group.name.toLowerCase());
    final result = await _promptArtistName(
      context,
      title: group.isUnknown ? '给这批文件指定作者' : '修改作者名',
      message: group.items.isEmpty
          ? '「${group.name}」名下还没有文件，可以改个名字，或者直接删除。'
          : '会把「${group.name}」名下 ${group.items.length} 个文件的作者一起改掉；填一个已有的作者名就是合并过去。',
      initial: group.isUnknown ? '' : group.name,
      known: known,
    );
    if (result == null || !mounted) return;
    final changed = await library.renameArtist(
      _kind,
      from: group.name,
      items: group.items,
      to: result,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          result.isEmpty ? '已恢复成文件自带的作者' : '已把 $changed 个文件归到「$result」',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final grouped = _groupArtists(library, _kind);
    final keys = _orderedArtistKeys(grouped, library, _kind);
    final hidden = library.hiddenArtists(_kind);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('管理作者')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
          children: [
            Row(
              children: [
                _ChoiceChip(
                  label: '音频',
                  icon: Icons.library_music_rounded,
                  selected: _kind == MediaKind.audio,
                  accent: AppColors.primary,
                  onTap: () => setState(() => _kind = MediaKind.audio),
                ),
                const SizedBox(width: 10),
                _ChoiceChip(
                  label: '视频',
                  icon: Icons.movie_rounded,
                  selected: _kind == MediaKind.video,
                  accent: AppColors.videoAccent,
                  onTap: () => setState(() => _kind = MediaKind.video),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  '作者',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '共 ${keys.length} 位',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (keys.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '还没有识别出任何作者',
                  style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: keys.length,
                onReorderItem: (oldIndex, newIndex) => _reorder(
                  library,
                  oldIndex,
                  newIndex,
                  [for (final key in keys) grouped[key]!.name],
                ),
                itemBuilder: (context, index) {
                  final group = grouped[keys[index]]!;
                  return _ManageArtistRow(
                    key: ValueKey<String>('artist-${keys[index]}'),
                    index: index,
                    kind: _kind,
                    group: group,
                    accent: _accent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _ArtistSongsPage(
                          artist: group.name,
                          items: group.items,
                          manageKind: _kind,
                          artistKey: keys[index],
                        ),
                      ),
                    ),
                    onRename: () => _rename(library, group),
                    onDelete: () => _hide(library, group),
                  );
                },
              ),
            const SizedBox(height: 14),
            _GlassSection(
              title: '新增作者',
              subtitle: '手动建一位还没识别出来的作者，之后可以往里面放文件',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: '输入新的作者名',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _create(library),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _create(library),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新增'),
                  ),
                ],
              ),
            ),
            if (hidden.isNotEmpty) ...[
              const SizedBox(height: 14),
              _GlassSection(
                title: '已删除的作者',
                subtitle: '点一下可以让它重新显示',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in hidden)
                      ActionChip(
                        avatar: const Icon(Icons.visibility_rounded, size: 16),
                        label: Text(name),
                        onPressed: () => library.restoreArtist(_kind, name),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 管理页里的一行作者：封面 + 名字 + 改名 / 删除 / 拖动手柄。
class _ManageArtistRow extends StatelessWidget {
  const _ManageArtistRow({
    super.key,
    required this.index,
    required this.kind,
    required this.group,
    required this.accent,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final int index;
  final MediaKind kind;
  final _ArtistGroup group;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final first = group.items.isEmpty ? null : group.items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: GlassPanel(
            borderRadius: BorderRadius.circular(20),
            tint: AppColors.card,
            blur: 16,
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: [
                MediaArtwork(
                  kind: kind,
                  size: 46,
                  radius: 13,
                  artworkPath: first?.artworkPath,
                  seed: group.name,
                  label: group.name.isEmpty ? '?' : group.name.substring(0, 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        group.items.isEmpty
                            ? '还没有文件'
                            : '${group.items.length} 个文件 点一下整理',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.drive_file_rename_outline_rounded,
                  tooltip: '修改作者名',
                  color: accent,
                  onPressed: onRename,
                ),
                _RoundIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: '删除作者',
                  color: AppColors.inkSoft,
                  onPressed: onDelete,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppColors.inkSoft,
                      size: 20,
                    ),
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

/// 一排紧凑的小图标按钮。
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      icon: Icon(icon, size: 18, color: color),
    );
  }
}

/// 管理页里的分组卡片（毛玻璃 + 标题 + 副标题）。
class _GlassSection extends StatelessWidget {
  const _GlassSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(20),
      tint: AppColors.card,
      blur: 16,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
