import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../utils/tag_reader.dart';

/// 文件列表的排序方式。
enum SortMode {
  az('A-Z'),
  artistAZ('作者 A-Z'),
  manual('手动');

  const SortMode(this.label);

  final String label;
}

/// 一个文件夹：对应首页里的一张光碟。
class MediaFolder {
  MediaFolder({
    required this.path,
    required this.name,
    required this.items,
    this.isCustom = false,
    this.isSpecial = false,
  });

  /// 文件夹完整路径（作为分组键）。
  final String path;

  /// 文件夹显示名。
  final String name;

  /// 该文件夹下的全部媒体文件。
  final List<MediaItem> items;

  /// 是否是用户自己创建的文件夹（只存在于应用里，不映射磁盘目录）。
  final bool isCustom;

  /// 是否是「喜欢」「全部文件」这类固定文件夹（不能改名 / 删除 / 拖动）。
  final bool isSpecial;

  int get count => items.length;

  /// 该文件夹的代表封面：优先文件夹内的封面图，其次第一首有封面的歌。
  String? get artworkPath {
    final folderCover = coverPath;
    if (folderCover != null) return folderCover;
    for (final item in items) {
      final artwork = item.artworkPath;
      if (artwork != null) return artwork;
    }
    return null;
  }

  static const List<String> _coverNames = [
    '1.jpg',
    'cover.jpg',
    'folder.jpg',
    '封面.jpg',
    'cover.png',
    '1.png',
  ];
  static final Map<String, String?> _coverCache = <String, String?>{};

  /// 文件夹内若存在封面图则返回其路径，否则返回 null（用应用图标兜底）。
  String? get coverPath {
    if (_coverCache.containsKey(path)) return _coverCache[path];
    String? found;
    if (path.isNotEmpty) {
      for (final name in _coverNames) {
        final candidate = '$path/$name';
        try {
          if (File(candidate).existsSync()) {
            found = candidate;
            break;
          }
        } catch (_) {
          // 忽略无法访问的路径。
        }
      }
    }
    _coverCache[path] = found;
    return found;
  }
}

/// 本地媒体库：负责导入、排序、保存与查询被导入的音视频文件。
class LibraryService extends ChangeNotifier {
  static const String _audioKey = 'melody.library.audio.v1';
  static const String _videoKey = 'melody.library.video.v1';
  static const String _audioSortKey = 'melody.sort.audio.v1';
  static const String _videoSortKey = 'melody.sort.video.v1';
  static const String _folderMetaKey = 'melody.folders.meta.v1';

  final List<MediaItem> _audio = <MediaItem>[];
  final List<MediaItem> _video = <MediaItem>[];
  SortMode _audioSort = SortMode.az;
  SortMode _videoSort = SortMode.az;

  /// 文件夹自定义顺序（按类型分别保存）。
  final Map<MediaKind, List<String>> _folderOrder = <MediaKind, List<String>>{};

  /// 置顶的文件夹（按类型分别保存）。
  final Map<MediaKind, List<String>> _folderPins = <MediaKind, List<String>>{};

  /// 文件夹的自定义名称（路径 -> 名称）。
  final Map<String, String> _folderNames = <String, String>{};

  /// 用户自己创建的文件夹（按类型分别保存，值为文件夹 id）。
  final Map<MediaKind, List<String>> _customFolders =
      <MediaKind, List<String>>{};

  /// 用户手动新增的作者文件夹（按类型分别保存，即使暂时没有文件也显示）。
  final Map<MediaKind, List<String>> _customArtists =
      <MediaKind, List<String>>{};

  /// 作者文件夹的自定义顺序（按类型分别保存，存作者名小写）。
  final Map<MediaKind, List<String>> _artistOrder = <MediaKind, List<String>>{};

  /// 被删除（隐藏）的作者（按类型分别保存，存作者名原文）。
  final Map<MediaKind, List<String>> _hiddenArtists =
      <MediaKind, List<String>>{};

  /// 自定义文件夹 id 的前缀，避免和真实目录路径撞车。
  static const String customFolderPrefix = 'custom:';

  /// 「喜欢」固定文件夹的键。
  static const String favoriteFolderKey = 'special:favorite';

  /// 「全部文件」固定文件夹的键。
  static const String allFolderKey = 'special:all';

  static bool isCustomFolderKey(String key) =>
      key.startsWith(customFolderPrefix);

  /// 是否是「喜欢」「全部文件」这类固定文件夹。
  static bool isSpecialFolderKey(String key) => key.startsWith('special:');

  /// 文件所属的文件夹键：被移动过就用移动后的文件夹，否则用真实目录。
  static String folderKeyOf(MediaItem item) => item.folderKey ?? item.location;

  /// 内嵌封面缓存目录，第一次用到时才创建。
  String? _artworkDir;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<MediaItem> _bucket(MediaKind kind) =>
      kind == MediaKind.audio ? _audio : _video;

  /// 获取某一类型的全部媒体（已按当前排序方式排列）。
  List<MediaItem> items(MediaKind kind) => List.unmodifiable(_bucket(kind));

  int count(MediaKind kind) => _bucket(kind).length;

  SortMode sortMode(MediaKind kind) =>
      kind == MediaKind.audio ? _audioSort : _videoSort;

  /// 从本地存储恢复媒体库，并清理已经不存在的文件。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _audio
      ..clear()
      ..addAll(_decode(prefs.getStringList(_audioKey)));
    _video
      ..clear()
      ..addAll(_decode(prefs.getStringList(_videoKey)));
    _audio.removeWhere((item) => !File(item.path).existsSync());
    _video.removeWhere((item) => !File(item.path).existsSync());
    _audioSort = _readSortMode(prefs.getString(_audioSortKey));
    _videoSort = _readSortMode(prefs.getString(_videoSortKey));
    _readFolderMeta(prefs.getString(_folderMetaKey));
    _applySort(_audio, _audioSort);
    _applySort(_video, _videoSort);
    _loaded = true;
    notifyListeners();
    // 之前导入的文件可能还没读过封面，进入页面后补齐，不阻塞启动。
    unawaited(_backfillArtwork());
  }

  /// 为缺少内嵌封面的已有文件补读一次封面与标签。
  Future<void> _backfillArtwork() async {
    final pending = <MediaItem>[];
    for (final item in <MediaItem>[..._audio, ..._video]) {
      final artwork = item.artworkPath;
      if (artwork != null && File(artwork).existsSync()) continue;
      pending.add(item);
    }
    if (pending.isEmpty) return;

    List<TagInfo> tags;
    try {
      tags = await readTagsBatch(
        pending.map((item) => item.path).toList(),
        artworkDir: await _artworkDirectory(),
      );
    } catch (_) {
      return;
    }

    var changed = false;
    for (var i = 0; i < pending.length; i++) {
      final info = tags[i];
      if (info.artworkPath == null && info.title == null) continue;
      final source = pending[i];
      final bucket = _bucket(source.kind);
      final index = bucket.indexWhere(
        (each) => _normalize(each.path) == _normalize(source.path),
      );
      if (index < 0) continue;
      bucket[index] = source.copyWith(
        tagTitle: info.title,
        tagArtist: info.artist,
        artworkPath: info.artworkPath,
      );
      changed = true;
    }
    if (!changed) return;
    notifyListeners();
    await _save();
  }

  /// 导入一批文件路径，返回实际新增的数量。可以随时重复导入。
  Future<int> importPaths(Iterable<String> paths, MediaKind kind) async {
    final bucket = _bucket(kind);
    final existing = bucket.map((item) => _normalize(item.path)).toSet();
    final fresh = <String>[];
    for (final path in paths) {
      final normalized = _normalize(path);
      if (existing.contains(normalized)) continue;
      if (kindForExtension(MediaItem.extensionOf(path)) != kind) continue;
      existing.add(normalized);
      fresh.add(path);
    }
    if (fresh.isEmpty) return 0;

    // 读取标签中的歌名、作者名与内嵌封面；失败时回退为文件名。
    List<TagInfo> tags;
    try {
      tags = await readTagsBatch(fresh, artworkDir: await _artworkDirectory());
    } catch (_) {
      tags = List<TagInfo>.filled(fresh.length, const TagInfo());
    }
    for (var i = 0; i < fresh.length; i++) {
      bucket.add(
        MediaItem.fromPath(
          fresh[i],
          kind: kind,
          tagTitle: tags[i].title,
          tagArtist: tags[i].artist,
          artworkPath: tags[i].artworkPath,
        ),
      );
    }
    // A-Z / 作者 A-Z 模式保持排序；手动模式下新导入的文件排在末尾。
    _applySort(bucket, sortMode(kind));
    notifyListeners();
    await _save();
    return fresh.length;
  }

  /// 切换排序方式。
  Future<void> setSortMode(MediaKind kind, SortMode mode) async {
    if (sortMode(kind) == mode) return;
    if (kind == MediaKind.audio) {
      _audioSort = mode;
    } else {
      _videoSort = mode;
    }
    _applySort(_bucket(kind), mode);
    notifyListeners();
    await _save();
    await _persistSortMode(kind, mode);
  }

  /// 按所在文件夹分组：每个文件夹对应首页里的一张光碟。
  /// 置顶的文件夹排在最前，其余按自定义顺序，最后按名称排序。
  List<MediaFolder> folders(MediaKind kind) {
    final grouped = <String, List<MediaItem>>{};
    for (final item in _bucket(kind)) {
      grouped.putIfAbsent(folderKeyOf(item), () => <MediaItem>[]).add(item);
    }
    // 自建的文件夹即使里面还没有文件也要显示出来。
    for (final id in _customOf(kind)) {
      grouped.putIfAbsent(id, () => <MediaItem>[]);
    }
    final order = _orderOf(kind);
    final pins = _pinsOf(kind);
    final result = grouped.entries
        .map(
          (entry) => MediaFolder(
            path: entry.key,
            name: folderName(entry.key),
            items: entry.value,
            isCustom: isCustomFolderKey(entry.key),
          ),
        )
        .toList();
    result.sort((a, b) {
      final pinA = pins.contains(a.path) ? 0 : 1;
      final pinB = pins.contains(b.path) ? 0 : 1;
      if (pinA != pinB) return pinA - pinB;
      final indexA = order.indexOf(a.path);
      final indexB = order.indexOf(b.path);
      if (indexA >= 0 && indexB >= 0) return indexA - indexB;
      if (indexA >= 0) return -1;
      if (indexB >= 0) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    // 「全部文件」在最前，「喜欢」紧随其后。
    final all = _bucket(kind);
    if (all.isNotEmpty) {
      result.insert(
        0,
        MediaFolder(
          path: favoriteFolderKey,
          name: '喜欢',
          items: all.where((item) => item.favorite).toList(),
          isSpecial: true,
        ),
      );
      result.insert(
        0,
        MediaFolder(
          path: allFolderKey,
          name: '全部文件',
          items: List<MediaItem>.unmodifiable(all),
          isSpecial: true,
        ),
      );
    }
    return result;
  }

  /// 标记 / 取消标记「喜欢」，返回切换后的状态。
  Future<bool> toggleFavorite(MediaItem item) async {
    final bucket = _bucket(item.kind);
    final index = _indexOf(bucket, item);
    if (index < 0) return false;
    final next = !bucket[index].favorite;
    bucket[index] = bucket[index].copyWith(favorite: next);
    notifyListeners();
    await _save();
    return next;
  }

  /// 文件夹的展示名称：优先自定义名称。
  String folderName(String path) {
    if (path == favoriteFolderKey) return '喜欢';
    if (path == allFolderKey) return '全部文件';
    final renamed = _folderNames[path];
    if (renamed != null && renamed.isNotEmpty) return renamed;
    if (isCustomFolderKey(path)) return '新建文件夹';
    return _folderName(path);
  }

  List<String> _customOf(MediaKind kind) =>
      _customFolders.putIfAbsent(kind, () => <String>[]);

  /// 新建一个自建文件夹，返回它的键。
  Future<String> createFolder(MediaKind kind, String name) async {
    final id = '$customFolderPrefix${DateTime.now().microsecondsSinceEpoch}';
    _customOf(kind).add(id);
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) _folderNames[id] = trimmed;
    notifyListeners();
    await _saveFolderMeta();
    return id;
  }

  List<String> _artistsOf(MediaKind kind) =>
      _customArtists.putIfAbsent(kind, () => <String>[]);

  /// 用户手动新增的作者文件夹名（即使还没有文件也显示）。
  List<String> customArtists(MediaKind kind) =>
      List.unmodifiable(_artistsOf(kind));

  /// 新增一个作者文件夹；已存在（不区分大小写）时忽略。
  Future<void> addCustomArtist(MediaKind kind, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final list = _artistsOf(kind);
    if (list.any((each) => each.toLowerCase() == trimmed.toLowerCase())) return;
    list.add(trimmed);
    notifyListeners();
    await _saveFolderMeta();
  }

  /// 删除一个手动新增的作者文件夹（不影响文件本身的作者信息）。
  Future<void> removeCustomArtist(MediaKind kind, String name) async {
    final list = _artistsOf(kind);
    final before = list.length;
    list.removeWhere((each) => each.toLowerCase() == name.toLowerCase());
    if (list.length == before) return;
    notifyListeners();
    await _saveFolderMeta();
  }

  /// 调整某个文件所属的作者；传空表示恢复成文件自带的信息。
  Future<void> setItemArtist(MediaItem item, String? artist) =>
      updateItemInfo(item, title: item.customTitle, artist: artist);

  List<String> _artistOrderOf(MediaKind kind) =>
      _artistOrder.putIfAbsent(kind, () => <String>[]);

  List<String> _hiddenOf(MediaKind kind) =>
      _hiddenArtists.putIfAbsent(kind, () => <String>[]);

  /// 作者文件夹的自定义顺序（存作者名小写）。
  List<String> artistOrder(MediaKind kind) =>
      List.unmodifiable(_artistOrderOf(kind));

  /// 被删除（隐藏）的作者名，不再出现在按作者列表里。
  List<String> hiddenArtists(MediaKind kind) =>
      List.unmodifiable(_hiddenOf(kind));

  /// 删除某位作者：隐藏它，不再显示该作者的文件分组。
  Future<void> hideArtist(MediaKind kind, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final key = trimmed.toLowerCase();
    final hidden = _hiddenOf(kind);
    if (!hidden.any((each) => each.toLowerCase() == key)) hidden.add(trimmed);
    _artistsOf(kind).removeWhere((each) => each.toLowerCase() == key);
    _artistOrderOf(kind).remove(key);
    notifyListeners();
    await _saveFolderMeta();
  }

  /// 取消隐藏某位作者。
  Future<void> restoreArtist(MediaKind kind, String name) async {
    final key = name.trim().toLowerCase();
    final hidden = _hiddenOf(kind);
    final before = hidden.length;
    hidden.removeWhere((each) => each.toLowerCase() == key);
    if (hidden.length == before) return;
    notifyListeners();
    await _saveFolderMeta();
  }

  /// 保存作者文件夹的新顺序（传入按显示顺序排列的作者名）。
  Future<void> reorderArtists(MediaKind kind, List<String> orderedNames) async {
    _artistOrderOf(kind)
      ..clear()
      ..addAll(orderedNames.map((each) => each.trim().toLowerCase()));
    notifyListeners();
    await _saveFolderMeta();
  }

  /// 修改单个文件的歌名 / 作者名；传空表示恢复成文件自带的信息。
  Future<void> updateItemInfo(
    MediaItem item, {
    required String? title,
    required String? artist,
  }) async {
    final bucket = _bucket(item.kind);
    final index = _indexOf(bucket, item);
    if (index < 0) return;
    final source = bucket[index];
    bucket[index] = MediaItem(
      path: source.path,
      kind: source.kind,
      id: source.id,
      size: source.size,
      tagTitle: source.tagTitle,
      tagArtist: source.tagArtist,
      artworkPath: source.artworkPath,
      customTitle: _clean(title),
      customArtist: _clean(artist),
      folderKey: source.folderKey,
      favorite: source.favorite,
    );
    _applySort(bucket, sortMode(item.kind));
    notifyListeners();
    await _save();
  }

  /// 把一批文件移动到指定文件夹；folderKey 传空表示回到文件真实所在目录。
  Future<int> moveItems(List<MediaItem> items, String folderKey) async {
    if (items.isEmpty) return 0;
    final target = folderKey.isEmpty ? null : folderKey;
    final matched = _matcherFor(items);
    var moved = 0;
    for (final kind in MediaKind.values) {
      final bucket = _bucket(kind);
      for (var i = 0; i < bucket.length; i++) {
        if (!matched(bucket[i])) continue;
        bucket[i] = _withFolder(bucket[i], target);
        moved++;
      }
    }
    if (moved == 0) return 0;
    notifyListeners();
    await _save();
    return moved;
  }

  /// 把一批文件复制到指定文件夹：原位置保留，目标文件夹里多出一份。
  Future<int> copyItems(List<MediaItem> items, String folderKey) async {
    if (items.isEmpty || folderKey.isEmpty) return 0;
    var copied = 0;
    for (final item in items) {
      if (folderKeyOf(item) == folderKey) continue;
      _bucket(item.kind).add(
        MediaItem(
          path: item.path,
          kind: item.kind,
          id: _newId(),
          size: item.size,
          tagTitle: item.tagTitle,
          tagArtist: item.tagArtist,
          artworkPath: item.artworkPath,
          customTitle: item.customTitle,
          customArtist: item.customArtist,
          folderKey: folderKey,
          favorite: item.favorite,
        ),
      );
      copied++;
    }
    if (copied == 0) return 0;
    notifyListeners();
    await _save();
    return copied;
  }

  /// 只替换文件所属的文件夹，其余信息保持不变。
  MediaItem _withFolder(MediaItem item, String? key) => MediaItem(
    path: item.path,
    kind: item.kind,
    id: item.id,
    size: item.size,
    tagTitle: item.tagTitle,
    tagArtist: item.tagArtist,
    artworkPath: item.artworkPath,
    customTitle: item.customTitle,
    customArtist: item.customArtist,
    folderKey: key,
    favorite: item.favorite,
  );

  /// 只替换自定义作者名，其余信息保持不变。
  MediaItem _withArtist(MediaItem item, String? artist) => MediaItem(
    path: item.path,
    kind: item.kind,
    id: item.id,
    size: item.size,
    tagTitle: item.tagTitle,
    tagArtist: item.tagArtist,
    artworkPath: item.artworkPath,
    customTitle: item.customTitle,
    customArtist: artist,
    folderKey: item.folderKey,
    favorite: item.favorite,
  );

  /// 把某一组文件统一归到新的作者名下（改名，或合并到另一位作者）。
  /// [items] 是这组文件当前的记录，按 id / 路径定位，所以「未知作者」
  /// 这种没有名字的分组也能改。[to] 传空表示恢复成文件自带的作者信息。
  Future<int> renameArtist(
    MediaKind kind, {
    required String from,
    required List<MediaItem> items,
    required String? to,
  }) async {
    final key = from.trim().toLowerCase();
    final target = _clean(to);
    if (target != null && key.isNotEmpty && target.toLowerCase() == key) {
      return 0;
    }

    final bucket = _bucket(kind);
    final matched = _matcherFor(items);
    var changed = 0;
    for (var i = 0; i < bucket.length; i++) {
      if (!matched(bucket[i])) continue;
      bucket[i] = _withArtist(bucket[i], target);
      changed++;
    }

    // 手动新增的作者文件夹与排序位置也要跟着改名。
    final folders = _artistsOf(kind);
    final hadFolder = folders.any((each) => each.toLowerCase() == key);
    final order = _artistOrderOf(kind);
    final index = order.indexOf(key);
    if (hadFolder || index >= 0) {
      folders.removeWhere((each) => each.toLowerCase() == key);
      if (index >= 0) order.removeAt(index);
      if (target != null) {
        final targetKey = target.toLowerCase();
        if (!folders.any((each) => each.toLowerCase() == targetKey)) {
          folders.add(target);
        }
        if (index >= 0 && !order.contains(targetKey)) {
          order.insert(index.clamp(0, order.length), targetKey);
        }
      }
    }

    if (changed == 0 && !hadFolder) return 0;
    _applySort(bucket, sortMode(kind));
    notifyListeners();
    await _save();
    await _saveFolderMeta();
    return changed;
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  bool isFolderPinned(MediaKind kind, String path) =>
      _pinsOf(kind).contains(path);

  List<String> _orderOf(MediaKind kind) =>
      _folderOrder.putIfAbsent(kind, () => <String>[]);

  List<String> _pinsOf(MediaKind kind) =>
      _folderPins.putIfAbsent(kind, () => <String>[]);

  /// 置顶 / 取消置顶一个文件夹。
  Future<void> setFolderPinned(
    MediaKind kind,
    String path, {
    required bool pinned,
  }) async {
    final pins = _pinsOf(kind);
    pins.remove(path);
    if (pinned) pins.insert(0, path);
    notifyListeners();
    await _saveFolderMeta();
  }

  /// 重命名文件夹（只改显示名，不动磁盘）。传空则恢复默认名称。
  Future<void> renameFolder(String path, String? name) async {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _folderNames.remove(path);
    } else {
      _folderNames[path] = trimmed;
    }
    notifyListeners();
    await _saveFolderMeta();
  }

  /// 从媒体库移除整个文件夹（不会删除磁盘上的原文件）。
  /// 自建文件夹只解散容器，里面的文件回到各自的真实目录。
  Future<void> deleteFolder(MediaKind kind, String path) async {
    if (isSpecialFolderKey(path)) return;
    final bucket = _bucket(kind);
    if (isCustomFolderKey(path)) {
      for (var i = 0; i < bucket.length; i++) {
        if (bucket[i].folderKey == path) {
          bucket[i] = _withFolder(bucket[i], null);
        }
      }
    } else {
      bucket.removeWhere((item) => folderKeyOf(item) == path);
    }
    _customOf(kind).remove(path);
    _orderOf(kind).remove(path);
    _pinsOf(kind).remove(path);
    _folderNames.remove(path);
    notifyListeners();
    await _save();
    await _saveFolderMeta();
  }

  /// 拖动调整文件夹顺序（只影响当前类型）。
  Future<void> reorderFolders(
    MediaKind kind,
    List<MediaFolder> visible,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    final order = _orderOf(kind);
    final paths = visible.map((folder) => folder.path).toList();
    final moved = paths.removeAt(oldIndex);
    paths.insert(newIndex.clamp(0, paths.length), moved);
    final rest = order.where((path) => !paths.contains(path)).toList();
    order
      ..clear()
      ..addAll(paths)
      ..addAll(rest);
    notifyListeners();
    await _saveFolderMeta();
  }

  static String _folderName(String location) {
    if (location.isEmpty) return '未知文件夹';
    final index = location.lastIndexOf('/');
    final name = index >= 0 ? location.substring(index + 1) : location;
    return name.isEmpty ? '未知文件夹' : name;
  }

  /// 在某一组（文件夹）内手动拖动排序，其余文件夹的顺序不受影响。
  Future<void> reorder(
    MediaKind kind,
    List<MediaItem> visible,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    final bucket = _bucket(kind);
    final matched = _matcherFor(visible);

    // 记录这些文件在总列表中所占的位置。
    final slots = <int>[];
    for (var i = 0; i < bucket.length; i++) {
      if (matched(bucket[i])) slots.add(i);
    }

    final reordered = List<MediaItem>.of(visible);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), moved);

    // 只把这一组的文件重新填回原来的位置，其他文件顺序保持不动。
    for (var i = 0; i < slots.length && i < reordered.length; i++) {
      bucket[slots[i]] = reordered[i];
    }

    // 手动拖动后自动切换为手动排序。
    if (kind == MediaKind.audio) {
      _audioSort = SortMode.manual;
    } else {
      _videoSort = SortMode.manual;
    }
    notifyListeners();
    await _save();
    await _persistSortMode(kind, SortMode.manual);
  }

  /// 从媒体库中移除单个文件（不会删除磁盘上的原文件）。
  Future<void> remove(MediaItem item) async {
    final bucket = _bucket(item.kind);
    final index = _indexOf(bucket, item);
    if (index < 0) return;
    bucket.removeAt(index);
    notifyListeners();
    await _save();
  }

  /// 清空某一类型。
  Future<void> clear(MediaKind kind) async {
    _bucket(kind).clear();
    notifyListeners();
    await _save();
  }

  /// 按指定排序方式重排列表；手动模式保持原有顺序。
  void _applySort(List<MediaItem> bucket, SortMode mode) {
    switch (mode) {
      case SortMode.az:
        _sortByTitle(bucket);
      case SortMode.artistAZ:
        _sortByArtist(bucket);
      case SortMode.manual:
        break;
    }
  }

  void _sortByTitle(List<MediaItem> bucket) {
    bucket.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
  }

  /// 按作者名 A-Z 排序，没有作者信息的排在最后。
  void _sortByArtist(List<MediaItem> bucket) {
    bucket.sort((a, b) {
      final left = a.artist?.toLowerCase();
      final right = b.artist?.toLowerCase();
      if (left == null && right == null) return _byTitle(a, b);
      if (left == null) return 1;
      if (right == null) return -1;
      final byArtist = left.compareTo(right);
      return byArtist != 0 ? byArtist : _byTitle(a, b);
    });
  }

  int _byTitle(MediaItem a, MediaItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());

  SortMode _readSortMode(String? raw) {
    if (raw == null) return SortMode.az;
    return SortMode.values.firstWhere(
      (each) => each.name == raw,
      orElse: () => SortMode.az,
    );
  }

  List<MediaItem> _decode(List<String>? raw) {
    if (raw == null) return <MediaItem>[];
    final result = <MediaItem>[];
    for (final line in raw) {
      try {
        result.add(
          MediaItem.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } catch (_) {
        // 忽略损坏的记录。
      }
    }
    return result;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _audioKey,
      _audio.map((item) => jsonEncode(item.toJson())).toList(),
    );
    await prefs.setStringList(
      _videoKey,
      _video.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> _persistSortMode(MediaKind kind, SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kind == MediaKind.audio ? _audioSortKey : _videoSortKey,
      mode.name,
    );
  }

  /// 读取文件夹的顺序 / 置顶 / 自定义名称。
  void _readFolderMeta(String? raw) {
    _folderOrder.clear();
    _folderPins.clear();
    _folderNames.clear();
    for (final kind in MediaKind.values) {
      _folderOrder[kind] = <String>[];
      _folderPins[kind] = <String>[];
      _customFolders[kind] = <String>[];
      _customArtists[kind] = <String>[];
      _artistOrder[kind] = <String>[];
      _hiddenArtists[kind] = <String>[];
    }
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      for (final kind in MediaKind.values) {
        final bucket = data[kind.name];
        if (bucket is Map) {
          _folderOrder[kind] =
              (bucket['order'] as List?)?.cast<String>() ?? <String>[];
          _folderPins[kind] =
              (bucket['pins'] as List?)?.cast<String>() ?? <String>[];
          _customFolders[kind] =
              (bucket['custom'] as List?)?.cast<String>() ?? <String>[];
          _customArtists[kind] =
              (bucket['artists'] as List?)?.cast<String>() ?? <String>[];
          _artistOrder[kind] =
              (bucket['artistOrder'] as List?)?.cast<String>() ?? <String>[];
          _hiddenArtists[kind] =
              (bucket['hidden'] as List?)?.cast<String>() ?? <String>[];
        }
      }
      final names = data['names'];
      if (names is Map) {
        names.forEach((key, value) {
          if (key is String && value is String) _folderNames[key] = value;
        });
      }
    } catch (_) {
      // 数据损坏时忽略，用默认顺序。
    }
  }

  Future<void> _saveFolderMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final kind in MediaKind.values) {
      data[kind.name] = <String, dynamic>{
        'order': _orderOf(kind),
        'pins': _pinsOf(kind),
        'custom': _customOf(kind),
        'artists': _artistsOf(kind),
        'artistOrder': _artistOrderOf(kind),
        'hidden': _hiddenOf(kind),
      };
    }
    data['names'] = _folderNames;
    await prefs.setString(_folderMetaKey, jsonEncode(data));
  }

  /// 内嵌封面的缓存目录（在主 isolate 取好路径，供后台 isolate 写入）。
  Future<String> _artworkDirectory() async {
    final cached = _artworkDir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/artwork');
    if (!directory.existsSync()) directory.createSync(recursive: true);
    _artworkDir = directory.path;
    return directory.path;
  }

  /// 定位一条记录：带 id 的按 id 找，否则按路径找（且必须同样是没 id 的记录）。
  int _indexOf(List<MediaItem> bucket, MediaItem item) {
    final id = item.id;
    if (id != null) return bucket.indexWhere((each) => each.id == id);
    final target = _normalize(item.path);
    return bucket.indexWhere(
      (each) => each.id == null && _normalize(each.path) == target,
    );
  }

  /// 为一组记录生成匹配器：带 id 的按 id 匹配，否则按路径匹配。
  bool Function(MediaItem) _matcherFor(List<MediaItem> items) {
    final ids = <String>{};
    final paths = <String>{};
    for (final item in items) {
      final id = item.id;
      if (id != null) {
        ids.add(id);
      } else {
        paths.add(_normalize(item.path));
      }
    }
    return (entry) {
      final id = entry.id;
      if (id != null) return ids.contains(id);
      return paths.contains(_normalize(entry.path));
    };
  }

  /// 「复制到文件夹」产生的副本编号，保证 id 唯一。
  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idSeq++}';

  int _idSeq = 0;

  static String _normalize(String path) =>
      path.replaceAll('\\', '/').toLowerCase();
}
