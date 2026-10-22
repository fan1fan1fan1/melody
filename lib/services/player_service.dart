import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';

/// 播放模式。
enum PlayMode {
  sequential('顺序播放'),
  listLoop('列表循环'),
  single('单曲循环'),
  shuffle('随机播放');

  const PlayMode(this.label);

  final String label;
}

/// 全局播放器：列表连续播放、进度、倍速、播放模式与定时关闭。
class PlayerService extends ChangeNotifier {
  PlayerService() {
    _player = Player();
    _controller = VideoController(_player);
    _bindStreams();
    unawaited(_restoreSettings());
  }

  static const List<double> speedOptions = <double>[
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  /// 音量可选范围（100 为标准音量，超过即增强）。
  static const double minVolume = 0;
  static const double maxVolume = 130;

  /// 默认音量：比标准音量略小，避免一上来声音偏大。
  static const double defaultVolume = 60;

  static const String _modeKey = 'melody.player.mode.v1';
  static const String _volumeKey = 'melody.player.volume.v1';

  final Random _random = Random();
  late final Player _player;
  late final VideoController _controller;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  /// 当前播放顺序（随机播放时会打乱）。
  List<MediaItem> _queue = const <MediaItem>[];

  /// 打乱之前的原始顺序，用于退出随机播放时恢复。
  List<MediaItem> _originalOrder = const <MediaItem>[];
  int _index = -1;
  bool _playing = false;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _rate = 1.0;
  double _volume = defaultVolume;
  PlayMode _mode = PlayMode.sequential;
  Timer? _sleepTimer;
  Duration? _sleepRemaining;

  Player get player => _player;
  VideoController get videoController => _controller;

  /// 每次真正开始播放一个文件时回调（用于记录播放历史与榜单）。
  void Function(MediaItem item)? onItemPlayed;

  List<MediaItem> get queue => List.unmodifiable(_queue);
  int get index => _index;
  bool get playing => _playing;
  bool get buffering => _buffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get rate => _rate;

  /// 当前音量（0 - 130，100 为标准音量）。
  double get volume => _volume;
  PlayMode get mode => _mode;
  Duration? get sleepRemaining => _sleepRemaining;
  bool get sleepTimerActive => _sleepTimer != null;

  bool get hasMedia => _index >= 0 && _index < _queue.length;
  MediaItem? get current => hasMedia ? _queue[_index] : null;
  MediaKind? get currentKind => current?.kind;
  bool get isVideo => currentKind == MediaKind.video;

  bool get hasNext => switch (_mode) {
    PlayMode.sequential => hasMedia && _index < _queue.length - 1,
    PlayMode.shuffle => _queue.length > 1,
    PlayMode.listLoop || PlayMode.single => _queue.isNotEmpty,
  };

  bool get hasPrevious => switch (_mode) {
    PlayMode.sequential => hasMedia && _index > 0,
    PlayMode.shuffle => _queue.length > 1,
    PlayMode.listLoop || PlayMode.single => _queue.isNotEmpty,
  };

  double get progress {
    final total = _duration.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _bindStreams() {
    _subscriptions.add(
      _player.stream.playing.listen((value) {
        if (value == _playing) return;
        _playing = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.stream.buffering.listen((value) {
        if (value == _buffering) return;
        _buffering = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((value) {
        _position = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.stream.duration.listen((value) {
        if (value == _duration) return;
        _duration = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.stream.rate.listen((value) {
        if (value == _rate) return;
        _rate = value;
        notifyListeners();
      }),
    );
    // 自动切歌 / 上一首 / 下一首时同步索引。
    _subscriptions.add(
      _player.stream.playlist.listen((playlist) {
        if (_queue.isEmpty) return;
        final current = playlist.index;
        if (current >= 0 && current < _queue.length && current != _index) {
          _index = current;
          _position = Duration.zero;
          onItemPlayed?.call(_queue[_index]);
          notifyListeners();
        }
      }),
    );
  }

  Media _toMedia(MediaItem item) => Media(
    Uri.file(item.path).toString(),
    extras: <String, dynamic>{'item': item},
  );

  Playlist _buildPlaylist(int index) =>
      Playlist(_queue.map(_toMedia).toList(), index: index);

  /// 用一个列表替换播放队列，并从 [startIndex] 开始连续播放。
  Future<void> playQueue(List<MediaItem> items, int startIndex) async {
    if (items.isEmpty) return;
    final start = startIndex.clamp(0, items.length - 1);
    final startItem = items[start];
    _originalOrder = List<MediaItem>.from(items);
    _queue = _mode == PlayMode.shuffle
        ? _shuffledOrder(items, startItem)
        : List<MediaItem>.from(items);
    final found = _queue.indexWhere((each) => each.path == startItem.path);
    _index = found < 0 ? 0 : found;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
    onItemPlayed?.call(_queue[_index]);
    await _player.open(_buildPlaylist(_index), play: true);
    await _player.setRate(_rate);
    await _player.setVolume(_volume);
    await _applyPlaylistMode();
  }

  /// 在当前队列中播放指定文件。
  Future<void> playItem(List<MediaItem> items, MediaItem item) async {
    final found = items.indexWhere((each) => each.path == item.path);
    await playQueue(items, found < 0 ? 0 : found);
  }

  /// 追加文件到播放列表；当前没有在播时直接开始播放。
  /// 返回真正追加进去的数量。
  Future<int> addToQueue(List<MediaItem> items) async {
    if (items.isEmpty) return 0;
    if (_queue.isEmpty || !hasMedia) {
      await playQueue(items, 0);
      return items.length;
    }
    final existing = _queue.map((each) => each.path).toSet();
    final fresh = items.where((each) => !existing.contains(each.path)).toList();
    if (fresh.isEmpty) return 0;
    _queue = List<MediaItem>.from(_queue)..addAll(fresh);
    _originalOrder = List<MediaItem>.from(_originalOrder)..addAll(fresh);
    notifyListeners();
    for (final item in fresh) {
      await _player.add(_toMedia(item));
    }
    return fresh.length;
  }

  Future<void> toggle() async {
    if (!hasMedia) return;
    await _player.playOrPause();
  }

  Future<void> resume() async {
    if (!hasMedia) return;
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_mode == PlayMode.single || _mode == PlayMode.listLoop) {
      await _player.jump((_index + 1) % _queue.length);
      return;
    }
    await _player.next();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_mode == PlayMode.single || _mode == PlayMode.listLoop) {
      await _player.jump((_index - 1 + _queue.length) % _queue.length);
      return;
    }
    if (_index == 0) {
      await seek(Duration.zero);
      return;
    }
    await _player.previous();
  }

  Future<void> seek(Duration position) async {
    _position = position;
    notifyListeners();
    await _player.seek(position);
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    notifyListeners();
    await _player.setRate(rate);
  }

  /// 调节音量（0 - 130）。设置后立即生效并记住。
  Future<void> setVolume(double volume) async {
    final value = volume.clamp(minVolume, maxVolume);
    if (value == _volume) return;
    _volume = value;
    notifyListeners();
    await _player.setVolume(value);
    await _persistVolume();
  }

  /// 切换播放模式。切换随机 / 非随机时会重排队列。
  Future<void> setMode(PlayMode mode) async {
    if (mode == _mode) return;
    final previous = _mode;
    _mode = mode;
    notifyListeners();
    unawaited(_persistMode());

    final item = current;
    if (item == null) {
      await _applyPlaylistMode();
      return;
    }

    final shuffleChanged =
        (mode == PlayMode.shuffle) != (previous == PlayMode.shuffle);
    await _applyPlaylistMode();
    if (!shuffleChanged) return;

    final savedPosition = _position;
    if (mode == PlayMode.shuffle) {
      _originalOrder = List<MediaItem>.from(_queue);
      _queue = _shuffledOrder(_queue, item);
    } else {
      _queue = _originalOrder.isNotEmpty
          ? List<MediaItem>.from(_originalOrder)
          : List<MediaItem>.from(_queue);
    }
    final found = _queue.indexWhere((each) => each.path == item.path);
    _index = found < 0 ? 0 : found;
    notifyListeners();
    await _player.open(_buildPlaylist(_index), play: _playing);
    await _player.setRate(_rate);
    if (savedPosition > Duration.zero) {
      await _player.seek(savedPosition);
    }
  }

  /// 开始定时关闭，到点自动暂停。
  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepRemaining = duration;
    notifyListeners();
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining =
          (_sleepRemaining ?? Duration.zero) - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        timer.cancel();
        _sleepTimer = null;
        _sleepRemaining = null;
        unawaited(_player.pause());
        notifyListeners();
        return;
      }
      _sleepRemaining = remaining;
      notifyListeners();
    });
  }

  /// 取消定时关闭。
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepRemaining = null;
    notifyListeners();
  }

  List<MediaItem> _shuffledOrder(List<MediaItem> items, MediaItem? first) {
    final rest = items.where((each) => each.path != first?.path).toList();
    rest.shuffle(_random);
    return [?first, ...rest];
  }

  Future<void> _applyPlaylistMode() async {
    // 本项目自行管理随机顺序，不使用播放器内置随机。
    await _player.setShuffle(false);
    switch (_mode) {
      case PlayMode.sequential:
      case PlayMode.shuffle:
        await _player.setPlaylistMode(PlaylistMode.none);
      case PlayMode.listLoop:
        await _player.setPlaylistMode(PlaylistMode.loop);
      case PlayMode.single:
        await _player.setPlaylistMode(PlaylistMode.single);
    }
  }

  Future<void> _persistMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, _mode.name);
  }

  Future<void> _persistVolume() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
  }

  Future<void> _restoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_modeKey);
    if (name != null) {
      _mode = PlayMode.values.firstWhere(
        (each) => each.name == name,
        orElse: () => PlayMode.sequential,
      );
      notifyListeners();
    }
    final savedVolume = prefs.getDouble(_volumeKey);
    _volume = (savedVolume ?? defaultVolume).clamp(minVolume, maxVolume);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
