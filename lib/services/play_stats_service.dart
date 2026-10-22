import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

/// 一条播放历史记录（只保留当天）。
class PlayHistoryEntry {
  const PlayHistoryEntry({
    required this.path,
    required this.title,
    required this.artist,
    required this.kind,
    required this.playedAt,
  });

  final String path;
  final String title;
  final String? artist;
  final MediaKind kind;
  final DateTime playedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'title': title,
    'artist': artist,
    'kind': kind.name,
    'playedAt': playedAt.millisecondsSinceEpoch,
  };

  factory PlayHistoryEntry.fromJson(Map<String, dynamic> json) =>
      PlayHistoryEntry(
        path: json['path'] as String? ?? '',
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String?,
        kind: MediaKind.values.byName(json['kind'] as String? ?? 'audio'),
        playedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['playedAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// 榜单里的一首歌。
class SongRank {
  const SongRank({required this.title, required this.count});

  final String title;
  final int count;
}

/// 榜单里的一位作者。
class ArtistRank {
  const ArtistRank({required this.name, required this.count});

  final String name;
  final int count;
}

/// 播放统计：当天历史记录 + 累计播放次数（榜单）。
class PlayStatsService extends ChangeNotifier {
  static const String _historyKey = 'melody.stats.history.v1';
  static const String _songCountsKey = 'melody.stats.songCounts.v1';
  static const String _songTitlesKey = 'melody.stats.songTitles.v1';
  static const String _artistCountsKey = 'melody.stats.artistCounts.v1';

  /// 没有识别出作者时的显示名。
  static const String unknownArtist = '未知作者';

  final List<PlayHistoryEntry> _history = <PlayHistoryEntry>[];
  final Map<String, int> _songCounts = <String, int>{};
  final Map<String, String> _songTitles = <String, String>{};
  final Map<String, int> _artistCounts = <String, int>{};

  /// 当天的播放历史（最近播放的在前）。
  List<PlayHistoryEntry> get history => List.unmodifiable(_history);

  /// 播放歌曲排行前十（按次数从高到低）。
  List<SongRank> get topSongs {
    final entries = _songCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in entries.take(10))
        SongRank(title: _songTitles[entry.key] ?? entry.key, count: entry.value),
    ];
  }

  /// 播放作者排行前十（按次数从高到低）。
  List<ArtistRank> get topArtists {
    final entries = _artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in entries.take(10))
        ArtistRank(name: entry.key, count: entry.value),
    ];
  }

  /// 从本地存储恢复统计，并清掉昨天的历史。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _decodeHistory(prefs.getStringList(_historyKey));
    _decodeCounts(prefs.getString(_songCountsKey), _songCounts);
    _decodeStrings(prefs.getString(_songTitlesKey), _songTitles);
    _decodeCounts(prefs.getString(_artistCountsKey), _artistCounts);
    _pruneHistory();
    notifyListeners();
  }

  /// 记录一次播放：累计歌曲 / 作者次数，并写入当天历史。
  void recordPlay(MediaItem item) {
    _songCounts[item.path] = (_songCounts[item.path] ?? 0) + 1;
    _songTitles[item.path] = item.title;

    final artist = item.artist;
    final artistName = (artist == null || artist.trim().isEmpty)
        ? unknownArtist
        : artist.trim();
    _artistCounts[artistName] = (_artistCounts[artistName] ?? 0) + 1;

    final now = DateTime.now();
    _history.removeWhere((entry) => entry.path == item.path);
    _history.insert(
      0,
      PlayHistoryEntry(
        path: item.path,
        title: item.title,
        artist: item.artist,
        kind: item.kind,
        playedAt: now,
      ),
    );
    _pruneHistory();
    notifyListeners();
    unawaited(_save());
  }

  /// 只保留今天（0 点之后）的记录。
  void _pruneHistory() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    _history.removeWhere((entry) => entry.playedAt.isBefore(startOfToday));
  }

  void _decodeHistory(List<String>? raw) {
    _history.clear();
    if (raw == null) return;
    for (final line in raw) {
      try {
        _history.add(
          PlayHistoryEntry.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } catch (_) {
        // 忽略损坏的记录。
      }
    }
  }

  void _decodeCounts(String? raw, Map<String, int> target) {
    target.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data.forEach((key, value) {
        if (value is num) target[key] = value.toInt();
      });
    } catch (_) {
      // 忽略损坏的数据。
    }
  }

  void _decodeStrings(String? raw, Map<String, String> target) {
    target.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data.forEach((key, value) {
        if (value is String) target[key] = value;
      });
    } catch (_) {
      // 忽略损坏的数据。
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _historyKey,
      _history.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
    await prefs.setString(_songCountsKey, jsonEncode(_songCounts));
    await prefs.setString(_songTitlesKey, jsonEncode(_songTitles));
    await prefs.setString(_artistCountsKey, jsonEncode(_artistCounts));
  }
}
