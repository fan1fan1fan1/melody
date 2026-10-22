import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

/// 从文件标签中读到的歌名、作者名与内嵌封面缓存路径。
class TagInfo {
  const TagInfo({this.title, this.artist, this.artworkPath});

  final String? title;
  final String? artist;

  /// 内嵌封面被写成的缓存图片路径，没有封面时为 null。
  final String? artworkPath;
}

/// 批量读取音频/视频文件的歌名、作者与内嵌封面（在后台 isolate 执行，避免卡顿）。
///
/// [artworkDir] 必须由主 isolate 通过 path_provider 取好后再传入，
/// 因为后台 isolate 无法直接调用 Flutter 插件。
Future<List<TagInfo>> readTagsBatch(
  List<String> paths, {
  required String artworkDir,
}) {
  if (paths.isEmpty) return Future.value(const <TagInfo>[]);
  return Isolate.run(() {
    final directory = Directory(artworkDir);
    if (!directory.existsSync()) directory.createSync(recursive: true);
    return paths.map((path) => _readTag(path, artworkDir)).toList();
  });
}

TagInfo _readTag(String path, String artworkDir) {
  String? title;
  String? artist;
  String? artworkPath;
  try {
    final meta = readMetadata(File(path), getImage: true);
    title = _clean(meta.title);
    artist = _clean(meta.artist);
    artworkPath = _cacheArtwork(meta.pictures, path, artworkDir);
  } catch (_) {
    // 标签损坏或格式不支持时忽略，回退到文件名。
  }

  // 没有标签信息时，尝试从「作者 - 歌名」形式的文件名里拆分。
  if (title == null && artist == null) {
    final base = _fileNameWithoutExtension(path);
    final parts = base.split(' - ');
    if (parts.length == 2) {
      final left = parts[0].trim();
      final right = parts[1].trim();
      final numeric = RegExp(r'^\d+$').hasMatch(left);
      if (left.isNotEmpty && right.isNotEmpty && !numeric) {
        artist = left;
        title = right;
      }
    }
  }

  return TagInfo(title: title, artist: artist, artworkPath: artworkPath);
}

/// 把内嵌封面写成缓存图片，返回其路径；没有封面时返回 null。
String? _cacheArtwork(
  List<Picture> pictures,
  String sourcePath,
  String artworkDir,
) {
  if (pictures.isEmpty) return null;
  final chosen = pictures.firstWhere(
    (each) => each.pictureType == PictureType.coverFront,
    orElse: () => pictures.first,
  );
  final bytes = chosen.bytes;
  if (bytes.isEmpty) return null;

  int size = 0;
  int modified = 0;
  try {
    final stat = File(sourcePath).statSync();
    size = stat.size;
    modified = stat.modified.millisecondsSinceEpoch;
  } catch (_) {
    // 取不到文件信息时依然缓存，只是缓存键少了这两项。
  }

  final target = File(
    '$artworkDir/${_cacheKey(sourcePath, size, modified)}'
    '${_extensionForMime(chosen.mimetype)}',
  );
  if (target.existsSync()) return target.path;
  try {
    target.writeAsBytesSync(bytes);
    return target.path;
  } catch (_) {
    return null;
  }
}

/// 稳定且跨进程一致的缓存键（FNV-1a 变体），避免 Dart 的 String.hashCode 跨进程不稳定。
String _cacheKey(String path, int size, int modified) {
  final input = '$path|$size|$modified';
  var hash = 0xcbf29ce484222325;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16);
}

String _extensionForMime(String mime) {
  final lower = mime.toLowerCase();
  if (lower.contains('png')) return '.png';
  if (lower.contains('gif')) return '.gif';
  if (lower.contains('bmp')) return '.bmp';
  if (lower.contains('webp')) return '.webp';
  return '.jpg';
}

String _fileNameWithoutExtension(String path) {
  final normalized = path.replaceAll('\\', '/');
  final name = normalized.substring(normalized.lastIndexOf('/') + 1);
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
