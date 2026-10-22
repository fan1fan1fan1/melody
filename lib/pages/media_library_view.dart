import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../utils/media_importer.dart';
import '../widgets/app_background.dart';
import '../widgets/disc_card.dart';
import '../widgets/glass_panel.dart';
import '../widgets/media_tile.dart';
import 'now_playing_page.dart';

/// 导入方式。
enum _ImportTarget { files, folder, scan }

/// 文件夹的操作。
enum _FolderAction { pin, unpin, rename, reorder, delete }

/// 音乐 / 视频页：一行一个文件夹，点进去是该文件夹的全部文件。
class MediaLibraryView extends StatefulWidget {
  const MediaLibraryView({super.key, required this.kind});

  final MediaKind kind;

  @override
  State<MediaLibraryView> createState() => MediaLibraryViewState();
}

class MediaLibraryViewState extends State<MediaLibraryView> {
  /// 当前打开的文件夹路径，null 表示显示文件夹列表。
  String? _folderPath;

  /// 搜索框控制器与当前关键词（文件夹列表页与文件夹内部共用）。
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool get _isAudio => widget.kind == MediaKind.audio;
  String get _title => _isAudio ? '音乐' : '视频';
  String get _unit => _isAudio ? '首' : '个';
  List<Color> get _rim => _isAudio ? AppColors.audioRim : AppColors.videoRim;
  Color get _accent => _isAudio ? AppColors.primary : AppColors.videoAccent;
  String get _searchHint => '输入关键字查询';

  /// 当前生效的搜索关键词（已去除首尾空格并转为小写），为空表示未搜索。
  String get _keyword => _query.trim().toLowerCase();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 系统返回键：正在文件夹里就先退回文件夹列表，返回 true 表示已经处理。
  bool handleSystemBack() {
    if (_folderPath != null) {
      _exitFolder();
      return true;
    }
    if (_query.isNotEmpty) {
      _clearSearch();
      return true;
    }
    return false;
  }

  /// 一个文件是否命中关键词：匹配歌名/视频名或作者名（忽略大小写）。
  bool _matchesItem(MediaItem item, String keyword) {
    if (item.title.toLowerCase().contains(keyword)) return true;
    final artist = item.artist;
    return artist != null && artist.toLowerCase().contains(keyword);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// 进入一个文件夹：清空搜索，避免带旧关键词进入。
  void _enterFolder(String path) {
    _searchController.clear();
    setState(() {
      _folderPath = path;
      _query = '';
    });
  }

  /// 返回文件夹列表，同时清空搜索。
  void _exitFolder() {
    _searchController.clear();
    setState(() {
      _folderPath = null;
      _query = '';
    });
  }

  Future<void> _import(_ImportTarget target) async {
    final library = context.read<LibraryService>();
    final messenger = ScaffoldMessenger.of(context);
    Timer? waitingTimer;
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? waitingBar;
    var waitingShown = false;

    // 开始计时：超过 1 秒还没完成就弹一个「请等待」。
    void armWaiting() {
      waitingTimer?.cancel();
      waitingTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted || waitingShown) return;
        waitingShown = true;
        waitingBar = messenger.showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: Duration(days: 1),
            content: Text('请等待…'),
          ),
        );
      });
    }

    void dismissWaiting() {
      waitingTimer?.cancel();
      waitingTimer = null;
      if (waitingShown) {
        waitingBar?.close();
        waitingBar = null;
        waitingShown = false;
      }
    }

    try {
      final List<String> paths;
      switch (target) {
        case _ImportTarget.files:
          paths = await MediaImporter.pickFiles(widget.kind);
        case _ImportTarget.folder:
          if (MediaImporter.supportsFolderImport) {
            paths = await MediaImporter.pickFolder(widget.kind);
          } else {
            armWaiting();
            paths = await _pickDeviceFolder();
          }
        case _ImportTarget.scan:
          armWaiting();
          paths = MediaImporter.supportsDeviceScan
              ? await MediaImporter.scanDevice(widget.kind)
              : await MediaImporter.scanDesktop(widget.kind);
      }
      if (paths.isEmpty) {
        dismissWaiting();
        return;
      }
      armWaiting();
      final added = await library.importPaths(paths, widget.kind);
      final skipped = paths.length - added;
      dismissWaiting();
      if (added > 0 && mounted) {
        // 本次导入只落在一个文件夹里时，直接进入该文件夹。
        final targets = paths.map(MediaItem.locationOf).toSet();
        setState(
          () => _folderPath = targets.length == 1 ? targets.first : null,
        );
      }
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            added > 0
                ? '已导入 $added 个文件${skipped > 0 ? '，跳过 $skipped 个已存在的文件' : ''}'
                : '没有新增文件（可能已存在或格式不支持）',
          ),
        ),
      );
    } catch (error) {
      dismissWaiting();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('导入失败：$error'),
        ),
      );
    }
  }

  /// 手机上不能选磁盘目录，改成列出手机里含媒体的文件夹让用户挑。
  Future<List<String>> _pickDeviceFolder() async {
    final all = await MediaImporter.scanDevice(widget.kind);
    if (all.isEmpty) return <String>[];
    final grouped = <String, List<String>>{};
    for (final path in all) {
      grouped
          .putIfAbsent(MediaItem.locationOf(path), () => <String>[])
          .add(path);
    }
    final folders = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!mounted) return <String>[];
    final selected = await showDialog<Set<String>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _DeviceFolderDialog(
        accent: _accent,
        folders: folders,
        counts: {
          for (final entry in grouped.entries) entry.key: entry.value.length,
        },
      ),
    );
    if (selected == null || selected.isEmpty) return <String>[];
    return [for (final folder in selected) ...?grouped[folder]];
  }

  /// 右上角「+」：中间弹出的选择框，三种导入方式。
  Future<void> _showImportMenu() async {
    final choice = await showDialog<_ImportTarget>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _ImportDialog(
        accent: _accent,
        deviceScan: MediaImporter.supportsDeviceScan,
      ),
    );
    if (!mounted || choice == null) return;
    await _import(choice);
  }

  Future<void> _showSortSheet(LibraryService library) async {
    final selected = await showModalBottomSheet<SortMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _SortSheet(current: library.sortMode(widget.kind), accent: _accent),
    );
    if (selected == null || !mounted) return;
    await library.setSortMode(widget.kind, selected);
    if (!mounted) return;
    // 选择手动排序时，进入独立页面拖动调整顺序。
    if (selected == SortMode.manual) {
      final folder = _findFolder(library.folders(widget.kind), _folderPath);
      if (folder != null) await _openReorderPage(folder);
      return;
    }
  }

  Future<void> _openReorderPage(MediaFolder folder) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ReorderPage(
          kind: widget.kind,
          folderPath: folder.path,
          accent: _accent,
          unit: _unit,
        ),
      ),
    );
  }

  Future<void> _openFolderReorderPage() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FolderReorderPage(
          kind: widget.kind,
          accent: _accent,
          unit: _unit,
          rim: _rim,
        ),
      ),
    );
  }

  Future<void> _addToQueue(List<MediaItem> items) async {
    final player = context.read<PlayerService>();
    final messenger = ScaffoldMessenger.of(context);
    final wasEmpty = !player.hasMedia;
    final added = await player.addToQueue(items);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          added == 0
              ? '已在播放列表中'
              : wasEmpty
              ? '已开始播放'
              : '已添加到播放列表',
        ),
      ),
    );
  }

  /// 点击一个文件开始播放；视频会同时打开播放抽屉，方便直接看画面。
  void _play(PlayerService player, List<MediaItem> items, MediaItem item) {
    player.playItem(items, item);
    if (item.kind == MediaKind.video) openNowPlaying(context);
  }

  MediaFolder? _findFolder(List<MediaFolder> folders, String? path) {
    if (path == null) return null;
    for (final folder in folders) {
      if (folder.path == path) return folder;
    }
    return null;
  }

  /// 长按（手机）或右键（电脑）文件夹：置顶 / 改名 / 调整顺序 / 删除。
  Future<void> _showFolderMenu(MediaFolder folder) async {
    final library = context.read<LibraryService>();
    final pinned = library.isFolderPinned(widget.kind, folder.path);
    final action = await showModalBottomSheet<_FolderAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolderActionsSheet(
        folderName: folder.name,
        pinned: pinned,
        accent: _accent,
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _FolderAction.pin:
        await library.setFolderPinned(widget.kind, folder.path, pinned: true);
      case _FolderAction.unpin:
        await library.setFolderPinned(widget.kind, folder.path, pinned: false);
      case _FolderAction.rename:
        await _renameFolder(folder);
      case _FolderAction.reorder:
        await _openFolderReorderPage();
      case _FolderAction.delete:
        await _deleteFolder(folder);
    }
  }

  /// 让用户输入一个名称（新建文件夹 / 重命名共用）。
  Future<String?> _promptName({
    required String title,
    required String hint,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  /// 新建一个自建文件夹，并直接进去。
  Future<void> _createCustomFolder() async {
    final library = context.read<LibraryService>();
    final name = await _promptName(title: '新建文件夹', hint: '输入文件夹名称');
    if (name == null || !mounted) return;
    final id = await library.createFolder(widget.kind, name);
    if (!mounted) return;
    _enterFolder(id);
  }

  Future<void> _renameFolder(MediaFolder folder) async {
    final library = context.read<LibraryService>();
    final name = await _promptName(
      title: '重命名文件夹',
      hint: '输入新的文件夹名称',
      initial: folder.name,
    );
    if (name == null) return;
    await library.renameFolder(folder.path, name);
  }

  /// 长按文件：修改歌曲名 / 作者名。
  Future<void> _editItem(MediaItem item) async {
    final library = context.read<LibraryService>();
    final titleController = TextEditingController(text: item.title);
    final artistController = TextEditingController(text: item.artist ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(labelText: _isAudio ? '歌曲名' : '视频名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistController,
              decoration: const InputDecoration(labelText: '作者名'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final title = titleController.text;
    final artist = artistController.text;
    titleController.dispose();
    artistController.dispose();
    if (saved != true) return;
    await library.updateItemInfo(item, title: title, artist: artist);
  }

  /// 长按 / 菜单：把这个文件换到其它文件夹（可新建）。
  Future<void> _moveItem(MediaItem item) async {
    final library = context.read<LibraryService>();
    final messenger = ScaffoldMessenger.of(context);
    final folders = library
        .folders(widget.kind)
        .where((folder) => !folder.isSpecial)
        .toList();
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoveTargetSheet(
        folders: folders,
        currentKey: LibraryService.folderKeyOf(item),
        moved: item.folderKey != null,
        accent: _accent,
      ),
    );
    if (target == null || !mounted) return;

    var key = target;
    if (target == _MoveTargetSheet.createNew) {
      final name = await _promptName(title: '新建文件夹', hint: '输入文件夹名称');
      if (name == null || !mounted) return;
      key = await library.createFolder(widget.kind, name);
    }
    final moved = await library.moveItems(<MediaItem>[item], key);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          moved == 0
              ? '移动失败，请重试'
              : key.isEmpty
              ? '已移回原来的文件夹'
              : '已移动到「${library.folderName(key)}」',
        ),
      ),
    );
  }

  /// 长按 / 菜单：把这个文件复制到其它文件夹（原位置保留，可新建）。
  Future<void> _copyItem(MediaItem item) async {
    final library = context.read<LibraryService>();
    final messenger = ScaffoldMessenger.of(context);
    final currentKey = LibraryService.folderKeyOf(item);
    final folders = library
        .folders(widget.kind)
        .where((folder) => !folder.isSpecial && folder.path != currentKey)
        .toList();
    final target = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoveTargetSheet(
        folders: folders,
        currentKey: currentKey,
        moved: false,
        copy: true,
        accent: _accent,
      ),
    );
    if (target == null || !mounted) return;

    var key = target;
    if (target == _MoveTargetSheet.createNew) {
      final name = await _promptName(title: '新建文件夹', hint: '输入文件夹名称');
      if (name == null || !mounted) return;
      key = await library.createFolder(widget.kind, name);
    }
    final copied = await library.copyItems(<MediaItem>[item], key);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          copied == 0 ? '复制失败，请重试' : '已复制到「${library.folderName(key)}」',
        ),
      ),
    );
  }

  Future<void> _deleteFolder(MediaFolder folder) async {
    final library = context.read<LibraryService>();
    final count = folder.count;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(folder.isCustom ? '解散文件夹' : '删除文件夹'),
        content: Text(
          folder.isCustom
              ? '将解散「${folder.name}」，里面的 $count $_unit会回到各自原来的文件夹，文件不会被删除。'
              : '将从列表中移除「${folder.name}」及其中的 $count $_unit，磁盘上的原文件不会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(folder.isCustom ? '解散' : '删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await library.deleteFolder(widget.kind, folder.path);
    if (!mounted) return;
    if (_folderPath == folder.path) setState(() => _folderPath = null);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final folders = library.folders(widget.kind);
    final current = _findFolder(folders, _folderPath);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          leading: current == null
              ? null
              : IconButton(
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _exitFolder,
                ),
          title: Text(current?.name ?? _title),
          actions: [
            if (current != null)
              _SortButton(
                mode: library.sortMode(widget.kind),
                accent: _accent,
                onTap: () => _showSortSheet(library),
              ),
            IconButton(
              tooltip: '导入',
              icon: const Icon(Icons.add_rounded, size: 26),
              onPressed: _showImportMenu,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            _SearchBar(
              controller: _searchController,
              accent: _accent,
              hint: _searchHint,
              onChanged: (value) => setState(() => _query = value),
              onClear: _clearSearch,
            ),
            Expanded(
              child: current == null
                  ? _buildFolders(context, folders)
                  : _buildList(library, current),
            ),
          ],
        ),
      ),
    );
  }

  /// 首页：一行一个文件夹，点进去是该文件夹的全部文件。
  Widget _buildFolders(BuildContext context, List<MediaFolder> folders) {
    return Stack(
      children: [
        const Positioned.fill(child: LogoWatermark()),
        if (folders.isEmpty)
          _buildEmptyState()
        else if (_keyword.isEmpty)
          _buildFolderList(context, folders)
        else
          _buildSearchResults(context, folders),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.album_rounded,
            size: 56,
            color: AppColors.inkSoft.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 14),
          const Text(
            '点击右上角 + 导入',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList(BuildContext context, List<MediaFolder> folders) {
    final player = context.watch<PlayerService>();
    final library = context.read<LibraryService>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 26),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 2, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '共 ${folders.length} 个文件夹',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _createCustomFolder,
                icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                label: const Text('新建文件夹'),
                style: TextButton.styleFrom(
                  foregroundColor: _accent,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        for (final folder in folders)
          _FolderRow(
            folder: folder,
            unit: _unit,
            rim: _rim,
            spinning: _isPlayingFolder(player, folder),
            cover: _coverOf(folder),
            pinned: library.isFolderPinned(widget.kind, folder.path),
            onTap: () => _enterFolder(folder.path),
            // 固定文件夹不能改名 / 删除 / 拖动。
            onLongPress: folder.isSpecial
                ? null
                : () => _showFolderMenu(folder),
          ),
      ],
    );
  }

  /// 正在播放的文件是否就在这个文件夹里（考虑被移动过的文件）。
  bool _isPlayingFolder(PlayerService player, MediaFolder folder) {
    final current = player.current;
    if (current == null) return false;
    return LibraryService.folderKeyOf(current) == folder.path;
  }

  /// 搜索首页：命中「文件夹名」的文件夹 + 去重后的文件（显示歌曲/作者/来自多个文件夹）。
  Widget _buildSearchResults(BuildContext context, List<MediaFolder> folders) {
    final keyword = _keyword;
    final player = context.watch<PlayerService>();
    final library = context.read<LibraryService>();
    // 「全部文件 / 喜欢」是聚合视图，不参与文件去重与文件夹名匹配。
    final realFolders = folders.where((folder) => !folder.isSpecial).toList();
    final matchedFolders = realFolders
        .where((folder) => folder.name.toLowerCase().contains(keyword))
        .toList();

    // 按物理文件路径去重：同一首歌出现在多个文件夹里也只显示一次。
    final byPath = <String, _SearchHit>{};
    for (final folder in realFolders) {
      for (final item in folder.items) {
        if (!_matchesItem(item, keyword)) continue;
        final key = item.path.toLowerCase();
        final hit = byPath.putIfAbsent(key, () => _SearchHit(item: item));
        hit.folders.add(folder.name);
      }
    }
    final hits = byPath.values.toList()
      ..sort(
        (a, b) => a.item.title.toLowerCase().compareTo(
          b.item.title.toLowerCase(),
        ),
      );
    final hitItems = <MediaItem>[for (final hit in hits) hit.item];

    if (matchedFolders.isEmpty && hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: AppColors.inkSoft.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '没有找到与「${_query.trim()}」相关的内容',
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 26),
      children: [
        if (matchedFolders.isNotEmpty) ...[
          _SectionTitle(
            text: '文件夹 ${matchedFolders.length}',
            accent: _accent,
          ),
          for (final folder in matchedFolders)
            _FolderRow(
              folder: folder,
              unit: _unit,
              rim: _rim,
              spinning: _isPlayingFolder(player, folder),
              cover: _coverOf(folder),
              pinned: library.isFolderPinned(widget.kind, folder.path),
              onTap: () => _enterFolder(folder.path),
              // 固定文件夹不能改名 / 删除 / 拖动。
              onLongPress: folder.isSpecial
                  ? null
                  : () => _showFolderMenu(folder),
            ),
        ],
        if (hits.isNotEmpty) ...[
          _SectionTitle(text: '文件 ${hits.length}', accent: _accent),
          for (final hit in hits)
            MediaTile(
              item: hit.item,
              footnote: _folderSourceText(hit.folders.toList()),
              active: player.current?.path == hit.item.path,
              playing: player.playing && player.current?.path == hit.item.path,
              favorite: hit.item.favorite,
              onTap: () => _play(player, hitItems, hit.item),
              onAddToQueue: () => _addToQueue(<MediaItem>[hit.item]),
              onToggleFavorite: () => library.toggleFavorite(hit.item),
              onEdit: () => _editItem(hit.item),
              onMove: () => _moveItem(hit.item),
              onCopy: () => _copyItem(hit.item),
              onRemove: () => library.remove(hit.item),
            ),
        ],
      ],
    );
  }

  /// 「来自 A、B、C」的小字文案。
  String _folderSourceText(List<String> folders) {
    final sorted = folders.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return '来自 ${sorted.join('、')}';
  }

  /// 文件夹封面：优先用文件自带的内嵌封面，其次文件夹里的封面图。
  ImageProvider _coverOf(MediaFolder folder) {
    final path = folder.artworkPath;
    if (path == null) return const AssetImage('1.jpg');
    return ResizeImage(FileImage(File(path)), width: 320);
  }

  /// 单个文件夹内的文件列表；有搜索关键词时只显示命中的文件。
  Widget _buildList(LibraryService library, MediaFolder folder) {
    final keyword = _keyword;
    final items = keyword.isEmpty
        ? folder.items
        : folder.items.where((item) => _matchesItem(item, keyword)).toList();
    final player = context.watch<PlayerService>();
    final mode = library.sortMode(widget.kind);
    // A-Z 与作者 A-Z 都按首字母分段显示右侧索引条；手动排序时自由拖动。
    final grouped = mode != SortMode.manual;

    if (items.isEmpty && keyword.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: AppColors.inkSoft.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '「${folder.name}」中没有匹配「${_query.trim()}」的$_title',
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  keyword.isEmpty
                      ? '共 ${items.length} $_unit'
                      : '匹配 ${items.length} $_unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: items.isEmpty
                    ? null
                    : () => player.playQueue(items, 0),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('全部播放'),
                style: TextButton.styleFrom(foregroundColor: _accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: grouped
              ? _AzSongList(
                  items: items,
                  accent: _accent,
                  byArtist: mode == SortMode.artistAZ,
                  onTapItem: (item) => _play(player, items, item),
                  onAddToQueue: (item) => _addToQueue(<MediaItem>[item]),
                  onToggleFavorite: (item) =>
                      context.read<LibraryService>().toggleFavorite(item),
                  onEditItem: _editItem,
                  onMoveItem: _moveItem,
                  onCopyItem: _copyItem,
                  onRemove: (item) =>
                      context.read<LibraryService>().remove(item),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _tile(player, items, index),
                ),
        ),
      ],
    );
  }

  Widget _tile(PlayerService player, List<MediaItem> items, int index) {
    final item = items[index];
    final active = player.current?.path == item.path;
    return MediaTile(
      item: item,
      active: active,
      playing: active && player.playing,
      favorite: item.favorite,
      onTap: () => _play(player, items, item),
      onAddToQueue: () => _addToQueue(<MediaItem>[item]),
      onToggleFavorite: () =>
          context.read<LibraryService>().toggleFavorite(item),
      onEdit: () => _editItem(item),
      onMove: () => _moveItem(item),
      onCopy: () => _copyItem(item),
      onRemove: () => context.read<LibraryService>().remove(item),
    );
  }
}

/// 顶部搜索框：半透明卡面 + 霓虹强调色，可一键清空。
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.accent,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final Color accent;
  final String hint;
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
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.inkSoft,
                  ),
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

/// 搜索结果的分区标题。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: accent.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// 搜索去重后的一条命中：一个物理文件 + 它出现在哪些文件夹里。
class _SearchHit {
  _SearchHit({required this.item});

  final MediaItem item;

  /// 该文件出现的文件夹名（去重）。
  final Set<String> folders = <String>{};
}

/// A-Z 模式下的分组列表：按首字母分段、段间留白，左侧显示字母，
/// 右侧是索引条（滚动 / 拖动时提示当前字母）。
class _AzSongList extends StatefulWidget {
  const _AzSongList({
    required this.items,
    required this.accent,
    required this.byArtist,
    required this.onTapItem,
    required this.onAddToQueue,
    required this.onToggleFavorite,
    required this.onEditItem,
    required this.onMoveItem,
    required this.onCopyItem,
    required this.onRemove,
  });

  final List<MediaItem> items;
  final Color accent;

  /// 按作者名排序时，首字母取作者名而不是歌名。
  final bool byArtist;
  final ValueChanged<MediaItem> onTapItem;
  final ValueChanged<MediaItem> onAddToQueue;
  final ValueChanged<MediaItem> onToggleFavorite;
  final ValueChanged<MediaItem> onEditItem;
  final ValueChanged<MediaItem> onMoveItem;
  final ValueChanged<MediaItem> onCopyItem;
  final ValueChanged<MediaItem> onRemove;

  @override
  State<_AzSongList> createState() => _AzSongListState();
}

class _AzSongListState extends State<_AzSongList> {
  static const double _rowHeight = 66;
  static const double _headerHeight = 30;
  static const double _groupGap = 12;
  static const double _topPadding = 2;
  static const double _bottomPadding = 22;

  final ScrollController _controller = ScrollController();
  bool _dragging = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 按首字母分组，保持 A-Z 排序下的自然顺序，「#」统一放在最后。
  List<MapEntry<String, List<MediaItem>>> _group() {
    final map = <String, List<MediaItem>>{};
    for (final item in widget.items) {
      final letter = widget.byArtist
          ? item.artistGroupLetter
          : item.groupLetter;
      map.putIfAbsent(letter, () => <MediaItem>[]).add(item);
    }
    final letters = map.entries.where((entry) => entry.key != '#').toList();
    final others = map.entries.where((entry) => entry.key == '#').toList();
    return <MapEntry<String, List<MediaItem>>>[...letters, ...others];
  }

  /// 每个字母分组的起始偏移量。
  Map<String, double> _offsets(List<MapEntry<String, List<MediaItem>>> groups) {
    final result = <String, double>{};
    var top = _topPadding;
    for (var i = 0; i < groups.length; i++) {
      result[groups[i].key] = top;
      top += _headerHeight + (i == 0 ? 0 : _groupGap);
      top += groups[i].value.length * _rowHeight;
    }
    return result;
  }

  String _letterAt(
    double offset,
    List<MapEntry<String, List<MediaItem>>> groups,
    Map<String, double> offsets,
  ) {
    if (groups.isEmpty) return '';
    var current = groups.first.key;
    for (final group in groups) {
      if (offset + 2 >= (offsets[group.key] ?? 0)) current = group.key;
    }
    return current;
  }

  void _jumpTo(String letter, Map<String, double> offsets) {
    final target = offsets[letter];
    if (target == null || !_controller.hasClients) return;
    _controller.jumpTo(target.clamp(0, _controller.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final groups = _group();
    if (groups.isEmpty) return const SizedBox.shrink();
    final offsets = _offsets(groups);
    final letters = groups.map((group) => group.key).toList();
    final current = _letterAt(
      _controller.hasClients ? _controller.offset : 0,
      groups,
      offsets,
    );

    return Stack(
      children: [
        ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.only(bottom: _bottomPadding),
          itemCount: groups.length + widget.items.length,
          itemBuilder: (context, index) =>
              _buildEntry(context, groups, index, player),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 34,
          child: _IndexBar(
            letters: letters,
            current: current,
            accent: widget.accent,
            onJump: (letter) => _jumpTo(letter, offsets),
            onDragStateChanged: (value) => setState(() => _dragging = value),
          ),
        ),
        if (_dragging)
          Positioned(
            right: 46,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.4),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Text(
                  current,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEntry(
    BuildContext context,
    List<MapEntry<String, List<MediaItem>>> groups,
    int index,
    PlayerService player,
  ) {
    var cursor = 0;
    var letterIndex = 0;
    for (final group in groups) {
      if (index == cursor) {
        return SizedBox(
          height: _headerHeight + (letterIndex == 0 ? 0 : _groupGap),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 22, bottom: 6),
              child: Text(
                group.key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: widget.accent.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        );
      }
      cursor++;
      for (final item in group.value) {
        if (index == cursor) {
          final active = player.current?.path == item.path;
          return SizedBox(
            height: _rowHeight,
            child: MediaTile(
              item: item,
              active: active,
              playing: active && player.playing,
              favorite: item.favorite,
              onTap: () => widget.onTapItem(item),
              onAddToQueue: () => widget.onAddToQueue(item),
              onToggleFavorite: () => widget.onToggleFavorite(item),
              onEdit: () => widget.onEditItem(item),
              onMove: () => widget.onMoveItem(item),
              onCopy: () => widget.onCopyItem(item),
              onRemove: () => widget.onRemove(item),
            ),
          );
        }
        cursor++;
      }
      letterIndex++;
    }
    return const SizedBox.shrink();
  }
}

/// 右侧字母索引条：点击或上下滑动可跳转，滑动时高亮并提示当前字母。
class _IndexBar extends StatefulWidget {
  const _IndexBar({
    required this.letters,
    required this.current,
    required this.accent,
    required this.onJump,
    required this.onDragStateChanged,
  });

  final List<String> letters;
  final String current;
  final Color accent;
  final ValueChanged<String> onJump;
  final ValueChanged<bool> onDragStateChanged;

  @override
  State<_IndexBar> createState() => _IndexBarState();
}

class _IndexBarState extends State<_IndexBar> {
  void _handle(double localY, double height) {
    if (widget.letters.isEmpty) return;
    final step = height / widget.letters.length;
    final index = (localY / step).floor().clamp(0, widget.letters.length - 1);
    widget.onJump(widget.letters[index]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handle(details.localPosition.dy, height),
          onVerticalDragStart: (details) {
            widget.onDragStateChanged(true);
            _handle(details.localPosition.dy, height);
          },
          onVerticalDragUpdate: (details) =>
              _handle(details.localPosition.dy, height),
          onVerticalDragEnd: (_) => widget.onDragStateChanged(false),
          onVerticalDragCancel: () => widget.onDragStateChanged(false),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final letter in widget.letters)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 1.5),
                  width: 18,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: letter == widget.current
                        ? widget.accent.withValues(alpha: 0.24)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: letter == widget.current
                          ? widget.accent
                          : AppColors.inkSoft,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 手动调整文件顺序的独立页面：拖动右侧手柄改变顺序。
class _ReorderPage extends StatelessWidget {
  const _ReorderPage({
    required this.kind,
    required this.folderPath,
    required this.accent,
    required this.unit,
  });

  final MediaKind kind;
  final String folderPath;
  final Color accent;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    MediaFolder? folder;
    for (final each in library.folders(kind)) {
      if (each.path == folderPath) folder = each;
    }
    final items = folder?.items ?? const <MediaItem>[];

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          title: Text(folder?.name ?? '调整顺序'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('完成'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ),
          ],
        ),
        body: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorderItem: (oldIndex, newIndex) =>
              library.reorder(kind, items, oldIndex, newIndex),
          itemBuilder: (context, index) => _row(context, items, index),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, List<MediaItem> items, int index) {
    final item = items[index];
    final player = context.watch<PlayerService>();
    final active = player.current?.path == item.path;
    return Padding(
      key: ValueKey<String>(item.path),
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: MediaTile(
              item: item,
              active: active,
              playing: active && player.playing,
              onTap: () => player.playItem(items, item),
              menuEnabled: false,
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.drag_handle_rounded,
                size: 22,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 手动调整文件夹顺序的独立页面。
class _FolderReorderPage extends StatelessWidget {
  const _FolderReorderPage({
    required this.kind,
    required this.accent,
    required this.unit,
    required this.rim,
  });

  final MediaKind kind;
  final Color accent;
  final String unit;
  final List<Color> rim;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    // 「喜欢」「全部文件」是固定文件夹，不参与拖动排序。
    final folders = library
        .folders(kind)
        .where((folder) => !folder.isSpecial)
        .toList();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          title: const Text('调整文件夹顺序'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('完成'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ),
          ],
        ),
        body: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
          buildDefaultDragHandles: false,
          itemCount: folders.length,
          onReorderItem: (oldIndex, newIndex) =>
              library.reorderFolders(kind, folders, oldIndex, newIndex),
          itemBuilder: (context, index) => _row(context, folders, index),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, List<MediaFolder> folders, int index) {
    final folder = folders[index];
    return Padding(
      key: ValueKey<String>(folder.path),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  DiscCard(
                    size: 40,
                    spinning: false,
                    rimColors: rim,
                    cover: folder.artworkPath == null
                        ? const AssetImage('1.jpg')
                        : ResizeImage(
                            FileImage(File(folder.artworkPath!)),
                            width: 240,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${folder.count} $unit',
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
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.drag_handle_rounded,
                size: 22,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 首页里的一行文件夹：左侧小光碟 + 名称 + 数量 + 进入箭头。
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.unit,
    required this.rim,
    required this.spinning,
    required this.cover,
    required this.pinned,
    required this.onTap,
    this.onLongPress,
  });

  final MediaFolder folder;
  final String unit;
  final List<Color> rim;
  final bool spinning;
  final ImageProvider cover;
  final bool pinned;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: folder.isSpecial
                    ? rim.first.withValues(alpha: 0.4)
                    : AppColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                DiscCard(
                  size: 44,
                  spinning: spinning,
                  rimColors: rim,
                  cover: cover,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (pinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.push_pin_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              folder.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (folder.isSpecial) ...[
                            const SizedBox(width: 6),
                            _DefaultTag(color: rim.first),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${folder.count} $unit',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 默认文件夹（全部文件 / 喜欢）的小标签，用来和其它文件夹区分开。
class _DefaultTag extends StatelessWidget {
  const _DefaultTag({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '默认',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

/// 排序方式图标。
IconData _sortIcon(SortMode mode) => switch (mode) {
  SortMode.az => Icons.sort_by_alpha_rounded,
  SortMode.artistAZ => Icons.person_outline_rounded,
  SortMode.manual => Icons.drag_indicator_rounded,
};

/// 排序按钮（固定在右上角，文字统一为「排序」）。
class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.mode,
    required this.accent,
    required this.onTap,
  });

  final SortMode mode;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_sortIcon(mode), size: 15, color: accent),
                  const SizedBox(width: 5),
                  Text(
                    '排序',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 排序方式选择面板。
class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current, required this.accent});

  final SortMode current;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.sheet,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '排序方式',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ),
            for (final mode in SortMode.values)
              ListTile(
                dense: true,
                leading: Icon(
                  _sortIcon(mode),
                  size: 20,
                  color: mode == current ? accent : AppColors.inkSoft,
                ),
                title: Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: mode == current
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: mode == current ? accent : AppColors.ink,
                  ),
                ),
                subtitle: mode == SortMode.manual
                    ? const Text(
                        '选择后进入新页面拖动调整',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                        ),
                      )
                    : null,
                trailing: mode == current
                    ? Icon(Icons.check_rounded, size: 18, color: accent)
                    : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
      ),
    );
  }
}

/// 文件夹长按 / 右键弹出的操作面板。
class _FolderActionsSheet extends StatelessWidget {
  const _FolderActionsSheet({
    required this.folderName,
    required this.pinned,
    required this.accent,
  });

  final String folderName;
  final bool pinned;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.sheet,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  folderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ),
            _tile(
              context,
              icon: pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              label: pinned ? '取消置顶' : '置顶到最前',
              value: pinned ? _FolderAction.unpin : _FolderAction.pin,
            ),
            _tile(
              context,
              icon: Icons.edit_rounded,
              label: '重命名',
              value: _FolderAction.rename,
            ),
            _tile(
              context,
              icon: Icons.swap_vert_rounded,
              label: '调整顺序',
              value: _FolderAction.reorder,
            ),
            _tile(
              context,
              icon: Icons.delete_outline_rounded,
              label: '从列表删除',
              value: _FolderAction.delete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required _FolderAction value,
    bool danger = false,
  }) {
    final color = danger
        ? const Color(0xFFFF6B8A)
        : (value == _FolderAction.pin ? accent : AppColors.ink);
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}

/// 导入选择弹窗：屏幕中间弹出，三种导入方式。
class _ImportDialog extends StatelessWidget {
  const _ImportDialog({required this.accent, required this.deviceScan});

  final Color accent;

  /// 安卓走系统媒体库扫描，桌面端走常见目录扫描。
  final bool deviceScan;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
      child: GlassPanel(
        borderRadius: BorderRadius.circular(26),
        tint: AppColors.sheet,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '导入',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            _option(
              context,
              icon: Icons.file_open_rounded,
              label: '导入文件',
              subtitle: '导入单个文件',
              value: _ImportTarget.files,
            ),
            const SizedBox(height: 8),
            _option(
              context,
              icon: Icons.folder_open_rounded,
              label: '导入文件夹',
              subtitle: '选择文件夹导入',
              value: _ImportTarget.folder,
            ),
            const SizedBox(height: 8),
            _option(
              context,
              icon: Icons.travel_explore_rounded,
              label: '扫描本机',
              subtitle: '自动扫描本机音视频文件夹',
              value: _ImportTarget.scan,
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required _ImportTarget value,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).pop(value),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手机上挑选文件夹的弹窗：列出手机里所有含媒体的文件夹，可多选。
class _DeviceFolderDialog extends StatefulWidget {
  const _DeviceFolderDialog({
    required this.accent,
    required this.folders,
    required this.counts,
  });

  final Color accent;
  final List<String> folders;
  final Map<String, int> counts;

  @override
  State<_DeviceFolderDialog> createState() => _DeviceFolderDialogState();
}

class _DeviceFolderDialogState extends State<_DeviceFolderDialog> {
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final allSelected =
        widget.folders.isNotEmpty && _selected.length == widget.folders.length;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 70),
      child: GlassPanel(
        borderRadius: BorderRadius.circular(26),
        tint: AppColors.sheet,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '选择文件夹',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (allSelected) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(widget.folders);
                    }
                  }),
                  child: Text(allSelected ? '取消全选' : '全选'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: widget.folders.length,
                itemBuilder: (context, index) {
                  final path = widget.folders[index];
                  final selected = _selected.contains(path);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() {
                          if (selected) {
                            _selected.remove(path);
                          } else {
                            _selected.add(path);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                          decoration: BoxDecoration(
                            color: selected
                                ? widget.accent.withValues(alpha: 0.16)
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.accent.withValues(
                                alpha: selected ? 0.45 : 0.16,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.folder_rounded,
                                size: 20,
                                color: selected
                                    ? widget.accent
                                    : AppColors.inkSoft,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nameOf(path),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    Text(
                                      path,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.counts[path] ?? 0}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已选 ${_selected.length} 个文件夹',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  child: const Text('导入'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _nameOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    final name = index >= 0 ? normalized.substring(index + 1) : normalized;
    return name.isEmpty ? normalized : name;
  }
}

/// 把文件换到其它文件夹时的选择面板。
class _MoveTargetSheet extends StatelessWidget {
  const _MoveTargetSheet({
    required this.folders,
    required this.currentKey,
    required this.moved,
    required this.accent,
    this.copy = false,
  });

  /// 新建文件夹的占位返回值。
  static const String createNew = '__create_new_folder__';

  final List<MediaFolder> folders;
  final String currentKey;

  /// 该文件是否已经被移动过（移动过才提供「回到原文件夹」）。
  final bool moved;

  /// true 表示「复制到文件夹」，文案与选项都按复制处理。
  final bool copy;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(24),
          tint: AppColors.sheet,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                copy ? '复制到文件夹' : '移动到文件夹',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    _row(
                      context,
                      icon: Icons.create_new_folder_rounded,
                      label: '新建文件夹…',
                      subtitle: copy ? '创建一个新文件夹并复制进去' : '创建一个新文件夹并移进去',
                      value: createNew,
                      highlight: false,
                    ),
                    if (moved && !copy)
                      _row(
                        context,
                        icon: Icons.undo_rounded,
                        label: '回到原文件夹',
                        subtitle: '取消这个文件的移动记录',
                        value: '',
                        highlight: false,
                      ),
                    for (final folder in folders)
                      _row(
                        context,
                        icon: folder.isCustom
                            ? Icons.folder_special_rounded
                            : Icons.folder_rounded,
                        label: folder.name,
                        subtitle: folder.isCustom
                            ? '自建文件夹 ${folder.count}'
                            : '${folder.count} ${folder.path}',
                        value: folder.path,
                        highlight: folder.path == currentKey,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required String value,
    required bool highlight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).pop(value),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: highlight
                  ? accent.withValues(alpha: 0.16)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: highlight ? 0.45 : 0.14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: highlight ? accent : AppColors.inkSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                if (highlight)
                  Icon(Icons.check_rounded, size: 18, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
