import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'player_service.dart';

/// 安卓桌面组件与 App 之间的桥。
///
/// 播放状态推给原生（原生写进桌面组件），组件上的按钮点回来在这里分发。
class WidgetService {
  WidgetService._();

  static const MethodChannel _channel = MethodChannel('meloday/widget');

  /// 组件上点了白噪音按钮时，通知界面切到白噪音页。
  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  /// 上一次推送过的状态，避免进度条每跳一下都推一次。
  static String _lastPushed = '';

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// 开始监听组件按钮。启动时顺带把 App 没起来时攒下的动作取回来。
  static Future<void> listen(PlayerService player) async {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return;
      await _handle(call.arguments as String? ?? '', player);
    });
    try {
      final pending = await _channel.invokeMethod<String>('takeAction');
      if (pending != null && pending.isNotEmpty) await _handle(pending, player);
    } catch (_) {
      // 桌面组件不可用时静默跳过。
    }
  }

  /// 把当前播放状态推给桌面组件，状态没变就什么都不做。
  static Future<void> pushMini(PlayerService player) async {
    if (!supported) return;
    final item = player.current;
    final title = item?.title ?? '';
    final playing = player.playing;
    final signature = '$title|${item?.path}|$playing'
        '|${player.hasPrevious}|${player.hasNext}';
    if (signature == _lastPushed) return;
    _lastPushed = signature;
    try {
      await _channel.invokeMethod<void>('updateMini', <String, dynamic>{
        'title': title,
        'artist': item?.artist ?? '',
        'playing': playing,
        'cover': item?.artworkPath,
        'hasPrev': player.hasPrevious,
        'hasNext': player.hasNext,
      });
    } catch (_) {
      // 桌面组件不可用时静默跳过。
    }
  }

  static Future<void> _handle(String action, PlayerService player) async {
    switch (action) {
      case 'toggle':
        await player.toggle();
      case 'next':
        await player.next();
      case 'prev':
        await player.previous();
      default:
        // noise:xxx —— 白噪音音频还没内置，先把界面带到白噪音页。
        if (action.startsWith('noise:')) requestedTab.value = 2;
    }
    await pushMini(player);
  }
}
