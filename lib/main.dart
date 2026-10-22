import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'pages/app_shell.dart';
import 'services/library_service.dart';
import 'services/play_stats_service.dart';
import 'services/player_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 调试期兜底：构建阶段出错时把异常画到屏幕上，避免 release 下只剩黑屏。
  ErrorWidget.builder = (details) =>
      _BootErrorApp(error: details.exception, stack: details.stack);

  try {
    MediaKit.ensureInitialized();
    final library = LibraryService();
    final stats = PlayStatsService();
    await library.load();
    await stats.load();

    final player = PlayerService();
    player.onItemPlayed = stats.recordPlay;

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LibraryService>.value(value: library),
          ChangeNotifierProvider<PlayerService>.value(value: player),
          ChangeNotifierProvider<PlayStatsService>.value(value: stats),
        ],
        child: const MelodyApp(),
      ),
    );
  } catch (error, stack) {
    runApp(_BootErrorApp(error: error, stack: stack));
  }
}

class MelodyApp extends StatelessWidget {
  const MelodyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melody',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}

/// 启动失败时展示错误信息，便于在手机上直接定位问题。
class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({this.error, this.stack});

  final Object? error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF07060D),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '启动失败',
                  style: TextStyle(
                    color: Color(0xFFFF6B81),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  '$error',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  '${stack ?? ''}',
                  style: const TextStyle(
                    color: Color(0xFF9E9AB6),
                    fontSize: 11,
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
