import 'dart:io';

/// 媒体类型：音频（mp3 等）或视频（mp4 等）。
enum MediaKind { audio, video }

/// 音频后缀集合。
const Set<String> kAudioExtensions = {
  'mp3',
  'm4a',
  'aac',
  'flac',
  'wav',
  'ogg',
  'oga',
  'opus',
  'wma',
  'aiff',
  'ape',
};

/// 视频后缀集合。
const Set<String> kVideoExtensions = {
  'mp4',
  'm4v',
  'mov',
  'mkv',
  'avi',
  'webm',
  'flv',
  '3gp',
  'ts',
  'wmv',
  'mpg',
  'mpeg',
};

/// 根据后缀判断媒体类型，无法识别时返回 null。
MediaKind? kindForExtension(String extension) {
  final ext = extension.toLowerCase();
  if (kAudioExtensions.contains(ext)) return MediaKind.audio;
  if (kVideoExtensions.contains(ext)) return MediaKind.video;
  return null;
}

/// 一个被导入的本地媒体文件。
class MediaItem {
  const MediaItem({
    required this.path,
    required this.kind,
    this.id,
    this.size = 0,
    this.tagTitle,
    this.tagArtist,
    this.artworkPath,
    this.customTitle,
    this.customArtist,
    this.folderKey,
    this.favorite = false,
  });

  final String path;
  final MediaKind kind;

  /// 同一条记录的唯一标识。直接导入的文件为 null（用路径区分）；
  /// 「复制到文件夹」产生的副本会各自带一个 id，互不影响。
  final String? id;
  final int size;

  /// 从文件标签中读到的歌名，可能为空。
  final String? tagTitle;

  /// 从文件标签中读到的作者名，可能为空。
  final String? tagArtist;

  /// 文件内嵌封面的缓存图片路径，没有封面时为 null。
  final String? artworkPath;

  /// 用户长按修改过的名称，优先于内嵌标签。
  final String? customTitle;

  /// 用户长按修改过的作者名，优先于内嵌标签。
  final String? customArtist;

  /// 被移动到某个文件夹后的分组键；为空表示按文件真实目录分组。
  final String? folderKey;

  /// 是否被标记为喜欢，「喜欢」文件夹里汇总显示。
  final bool favorite;

  /// 文件名（含后缀）。
  String get fileName {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index >= 0 ? normalized.substring(index + 1) : normalized;
  }

  /// 仅由文件名推导出的标题（去掉后缀）。
  String get fileTitle {
    final name = fileName;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// A-Z 分组用的首字母：拉丁字母取大写，其余（数字、中文、韩文等）归入「#」。
  String get groupLetter => _letterOf(title);

  /// 按作者名分组时的首字母，没有作者信息时归入「#」。
  String get artistGroupLetter => _letterOf(artist ?? '');

  static String _letterOf(String value) {
    final trimmed = value.trimLeft();
    if (trimmed.isEmpty) return '#';
    final code = trimmed.codeUnitAt(0);
    if (code >= 0x61 && code <= 0x7A) return String.fromCharCode(code - 0x20);
    if (code >= 0x41 && code <= 0x5A) return String.fromCharCode(code);
    return '#';
  }

  /// 生成封面用的首字符（用于没有内嵌封面时的个性化占位）。
  String get coverInitial {
    final value = title.trim();
    if (value.isEmpty) return '♪';
    return value.substring(0, 1).toUpperCase();
  }

  /// 显示用标题：优先用户自定义名称，其次标签歌名，最后文件名。
  String get title => customTitle ?? tagTitle ?? fileTitle;

  /// 作者名，未知时为 null。标签里没有时，尝试从歌名 / 文件名里识别。
  String? get artist {
    final custom = customArtist;
    if (custom != null) return custom;
    final tag = tagArtist;
    // 下载工具经常把推广语 / 歌名写进作者字段，不像人名（或者就是歌名
    // 本身）时直接丢弃，回退到从标题 / 文件名里识别。
    if (tag != null && _tagArtistTrusted(tag)) return tag;
    return guessArtist(tagTitle ?? fileTitle);
  }

  /// 标签里的作者字段是否可信。
  bool _tagArtistTrusted(String tag) {
    if (!isArtistLike(tag)) return false;
    if (tag == tagTitle) return false;
    // 没有标签标题时，作者字段若只是文件名里的一段，多半是复制过去的歌名。
    if (tagTitle == null && fileTitle.contains(tag)) return false;
    return true;
  }

  /// 列表副标题：作者 格式 大小（没有作者时省略作者）。
  String get subtitle {
    final base = '${extension.toUpperCase()} $sizeText';
    final name = tagArtist;
    return name == null ? base : '$name $base';
  }

  /// 小写后缀，不带点。
  String get extension {
    final name = fileName;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  }

  /// 文件所在目录。
  String get location => locationOf(path);

  /// 由路径推导所在目录（用于按文件夹分组）。
  static String locationOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index > 0 ? normalized.substring(0, index) : '';
  }

  /// 人类可读的文件大小。
  String get sizeText {
    if (size <= 0) return '未知大小';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = size.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  MediaItem copyWith({
    int? size,
    String? tagTitle,
    String? tagArtist,
    String? artworkPath,
    String? customTitle,
    String? customArtist,
    String? folderKey,
    bool? favorite,
  }) => MediaItem(
    path: path,
    kind: kind,
    id: id,
    size: size ?? this.size,
    tagTitle: tagTitle ?? this.tagTitle,
    tagArtist: tagArtist ?? this.tagArtist,
    artworkPath: artworkPath ?? this.artworkPath,
    customTitle: customTitle ?? this.customTitle,
    customArtist: customArtist ?? this.customArtist,
    folderKey: folderKey ?? this.folderKey,
    favorite: favorite ?? this.favorite,
  );

  Map<String, dynamic> toJson() => {
    'path': path,
    'kind': kind.name,
    'id': id,
    'size': size,
    'tagTitle': tagTitle,
    'tagArtist': tagArtist,
    'artworkPath': artworkPath,
    'customTitle': customTitle,
    'customArtist': customArtist,
    'folderKey': folderKey,
    'favorite': favorite,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      path: json['path'] as String,
      kind: MediaKind.values.byName(json['kind'] as String? ?? 'audio'),
      id: json['id'] as String?,
      size: (json['size'] as num?)?.toInt() ?? 0,
      tagTitle: json['tagTitle'] as String?,
      tagArtist: json['tagArtist'] as String?,
      artworkPath: json['artworkPath'] as String?,
      customTitle: json['customTitle'] as String?,
      customArtist: json['customArtist'] as String?,
      folderKey: json['folderKey'] as String?,
      favorite: json['favorite'] as bool? ?? false,
    );
  }

  /// 从磁盘路径创建，自动识别类型并读取文件大小。
  factory MediaItem.fromPath(
    String path, {
    MediaKind? kind,
    String? tagTitle,
    String? tagArtist,
    String? artworkPath,
  }) {
    final normalized = path.replaceAll('\\', '/');
    final dot = normalized.lastIndexOf('.');
    final slash = normalized.lastIndexOf('/');
    final ext = (dot > slash && dot >= 0)
        ? normalized.substring(dot + 1).toLowerCase()
        : '';
    var size = 0;
    try {
      size = File(path).lengthSync();
    } catch (_) {
      size = 0;
    }
    return MediaItem(
      path: path,
      kind: kind ?? kindForExtension(ext) ?? MediaKind.audio,
      size: size,
      tagTitle: tagTitle,
      tagArtist: tagArtist,
      artworkPath: artworkPath,
    );
  }

  static String extensionOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final dot = normalized.lastIndexOf('.');
    final slash = normalized.lastIndexOf('/');
    if (dot <= slash || dot < 0) return '';
    return normalized.substring(dot + 1).toLowerCase();
  }
}

/// 歌名 / 文件名里常见的、明显不是作者名的词。
const List<String> _artistNoise = [
  '歌单',
  '日推',
  '合集',
  '歌曲',
  '音乐',
  '热歌',
  '榜单',
  '排行',
  '精选',
  '无损',
  '高音质',
  '纯音乐',
  '钢琴',
  '伴奏',
  '翻唱',
  '现场',
  '直播',
  '字幕',
  '中字',
  '双语',
  '循环',
  '单曲',
  '专辑',
  '电台',
  '之子',
  '节目',
  '综艺',
  '超清',
  '完整版',
  '动态歌词',
  '歌词',
  'playlist',
  'music',
  'video',
  'audio',
  'official',
  'lyrics',
  'remix',
  'cover',
  // 下载站常见的推广语 / 描述词，绝不是人名。
  '试听',
  '推荐',
  '装备',
  '黑胶',
  '流行',
  '神曲',
  '官方',
  '宝宝',
  '小姐姐',
  '小哥哥',
  'hi-res',
  '4k',
];

/// 整段就等于这些词的，肯定不是作者名（多半是清晰度 / 格式标记）。
const List<String> _artistNoiseExact = [
  'dj',
  'mv',
  'hd',
  'hq',
  'live',
  'ost',
  'vip',
  'tv',
  'mp3',
  'flac',
  'wav',
];

final RegExp _markRe = RegExp(r'[【\[（(]([^】\]）)]{1,24})[】\]）)]');
final RegExp _quotedRe = RegExp(r'[《「“"][^》」”"]*[》」”"]');
final RegExp _possessiveRe = RegExp(r'^([\u4e00-\u9fa5A-Za-z0-9&.\-]{2,12})的');
final RegExp _spaceRe = RegExp(r'\s+');
final RegExp _upperTokenRe = RegExp(r'^[A-Z][A-Z0-9]+$');
final RegExp _quoteCharRe = RegExp(r'[《》「」“”"]');
final RegExp _digitStartRe = RegExp(r'^\d');
final RegExp _cjkRe = RegExp(r'[\u4e00-\u9fa5]');
final RegExp _titleWordRe = RegExp(r'[的是了我你他她它们这那吗呢]');

/// 判断一段文字像不像人名（供标签作者字段校验与文件名识别共用）。
bool isArtistLike(String value) => _isArtistLike(value);

/// 从歌名 / 文件名里猜作者名。
///
/// 很多下载来的文件没有作者标签，名字里却写着「【弹壳Danko】说唱巅峰…」
/// 「Karencici - 爱你但说实话」这类信息，这里尽量把它们识别出来。
String? guessArtist(String text) {
  final value = text.trim();
  if (value.isEmpty) return null;

  // 1. 【】/[] 里的内容，只要不像是歌单 / 节目名，就当成作者名。
  final marks = _markRe;
  for (final match in marks.allMatches(value)) {
    final inner = match.group(1)?.trim() ?? '';
    if (_isArtistLike(inner)) return inner;
  }

  // 1.5 标记前面的一段开头也常常是作者名：
  //     「Emei (官方字幕MV) xxx」里的 Emei、「Bruno Mars【Hi-Res】xxx」里的 Bruno Mars。
  final firstMark = marks.firstMatch(value);
  if (firstMark != null && firstMark.start > 0) {
    final prefix = value.substring(0, firstMark.start).trim();
    if (prefix.isNotEmpty &&
        prefix.length <= 20 &&
        prefix.split(_spaceRe).length <= 3 &&
        _isArtistLike(prefix)) {
      return prefix;
    }
  }

  // 2. 去掉括号标记和书名号里的内容，取分隔符前的一段。
  var rest = value.replaceAll(marks, ' ').trim();
  rest = rest.replaceAll(_quotedRe, ' ').trim();
  // 名字里本来带标明来源的括号，后面的「某某的…」才可能是作者。
  final hadMarker = rest != value;

  // 2a.「Karencici - 歌名」这类带空格的分隔符。
  for (final separator in const [' - ', ' – ', ' — ', ' | ', ' / ']) {
    final index = rest.indexOf(separator);
    if (index <= 0) continue;
    final head = rest.substring(0, index).trim();
    if (_isArtistLike(head)) return head;
  }

  // 2b.「Nelly/Kelly Rowland」「Karencici-歌名」这类没有空格的。
  for (final separator in const ['/', '|', '·', '-', '–', '—']) {
    final index = rest.indexOf(separator);
    if (index <= 0) continue;
    final head = rest.substring(0, index).trim();
    if (head.length >= 5 && _isArtistLike(head)) return head;
  }

  // 3.「【明日之子3】张钰琪的…」这类：取「的」前面一小段名字。
  if (hadMarker) {
    final possessive = _possessiveRe.firstMatch(rest);
    if (possessive != null && _isArtistLike(possessive.group(1)!)) {
      return possessive.group(1);
    }
  }

  // 4.「XG MOVE #4」这类：开头是一个全大写的短词。
  final head = rest.split(_spaceRe).first;
  if (head.length >= 2 &&
      head.length <= 5 &&
      _upperTokenRe.hasMatch(head) &&
      _isArtistLike(head)) {
    return head;
  }
  return null;
}

/// 判断一段文字像不像作者名。
bool _isArtistLike(String value) {
  final text = value.trim();
  if (text.isEmpty || text.length > 32) return false;
  final lower = text.toLowerCase();
  if (_artistNoiseExact.contains(lower)) return false;
  for (final word in _artistNoise) {
    if (lower.contains(word)) return false;
  }
  if (_quoteCharRe.hasMatch(text)) return false;
  if (_digitStartRe.hasMatch(text)) return false;
  // 中文名字一般不超过 6 个字，带「的 / 是 / 我」这类字的多半是歌名。
  final cjk = _cjkRe.allMatches(text).length;
  if (cjk > 6) return false;
  if (_titleWordRe.hasMatch(text)) return false;
  return true;
}
