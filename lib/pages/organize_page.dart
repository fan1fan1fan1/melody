import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/media_item.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/glass_panel.dart';

/// 整理页：把音频 / 视频整理成「名称 + 作者」的文本，导出为 txt。
/// 支持筛选类型、挑选文件夹、选择整理（排序）样式。
class OrganizePage extends StatefulWidget {
  const OrganizePage({super.key});

  @override
  State<OrganizePage> createState() => _OrganizePageState();
}

class _OrganizePageState extends State<OrganizePage> {
  MediaKind _kind = MediaKind.audio;
  final Set<String> _selected = <String>{};
  MediaKind? _selectedKind;
  SortMode _style = SortMode.az;
  bool _busy = false;

  Color get _accent =>
      _kind == MediaKind.audio ? AppColors.primary : AppColors.videoAccent;

  /// 切换类型时默认全选该类型下的文件夹。
  void _syncSelection(List<MediaFolder> folders) {
    if (_selectedKind == _kind) return;
    _selectedKind = _kind;
    _selected
      ..clear()
      ..addAll(folders.map((folder) => folder.path));
  }

  /// 选中范围内的文件，按整理样式排好序。
  List<MediaItem> _collect(List<MediaFolder> folders) {
    final result = <MediaItem>[];
    for (final folder in folders) {
      if (!_selected.contains(folder.path)) continue;
      result.addAll(folder.items);
    }
    switch (_style) {
      case SortMode.az:
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case SortMode.artistAZ:
        result.sort((a, b) {
          final left = a.artist?.toLowerCase();
          final right = b.artist?.toLowerCase();
          if (left == null && right == null) {
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          if (left == null) return 1;
          if (right == null) return -1;
          final byArtist = left.compareTo(right);
          return byArtist != 0
              ? byArtist
              : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      case SortMode.manual:
        break;
    }
    return result;
  }

  /// 一行文本：音频是「歌曲名 作者」，视频是「视频名」。
  String _lineOf(MediaItem item) {
    if (item.kind == MediaKind.video) return item.title;
    final artist = item.artist;
    return artist == null || artist.isEmpty
        ? item.title
        : '${item.title}  $artist';
  }

  Future<void> _export(List<MediaItem> items) async {
    if (items.isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final content = items.map(_lineOf).join('\n');
    final fileName = _kind == MediaKind.audio ? '音乐整理.txt' : '视频整理.txt';
    final bytes = Uint8List.fromList(utf8.encode(content));
    try {
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/plain',
        dialogTitle: '导出整理结果',
      );
      if (uri == null) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('已导出 ${items.length} 条到 ${uri.path}'),
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
    final folders = library.folders(_kind);
    _syncSelection(folders);
    final items = _collect(folders);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('整理')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            const _SectionLabel('类型'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ChoiceChip(
                    label: '音频',
                    icon: Icons.library_music_rounded,
                    selected: _kind == MediaKind.audio,
                    accent: AppColors.primary,
                    onTap: () => setState(() => _kind = MediaKind.audio),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChoiceChip(
                    label: '视频',
                    icon: Icons.movie_rounded,
                    selected: _kind == MediaKind.video,
                    accent: AppColors.videoAccent,
                    onTap: () => setState(() => _kind = MediaKind.video),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const _SectionLabel('文件夹'),
                const Spacer(),
                TextButton(
                  onPressed: folders.isEmpty
                      ? null
                      : () => setState(() {
                          final all = _selected.length == folders.length;
                          _selected.clear();
                          if (!all) {
                            _selected.addAll(
                              folders.map((folder) => folder.path),
                            );
                          }
                        }),
                  child: Text(
                    _selected.length == folders.length ? '取消全选' : '全选',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (folders.isEmpty)
              const _Hint('这一类型下还没有文件夹')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final folder in folders)
                    _ChoiceChip(
                      label: '${folder.name}（${folder.count}）',
                      selected: _selected.contains(folder.path),
                      accent: _accent,
                      onTap: () => setState(() {
                        if (!_selected.remove(folder.path)) {
                          _selected.add(folder.path);
                        }
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            const _SectionLabel('整理样式'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in SortMode.values)
                  _ChoiceChip(
                    label: mode.label == '手动' ? '保持当前顺序' : mode.label,
                    selected: _style == mode,
                    accent: _accent,
                    onTap: () => setState(() => _style = mode),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const _SectionLabel('预览'),
                const Spacer(),
                Text(
                  '共 ${items.length} 条',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GlassPanel(
              borderRadius: BorderRadius.circular(20),
              tint: AppColors.card,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: SizedBox(
                height: 240,
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          '选择文件夹后这里会显示整理结果',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            _lineOf(items[index]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy || items.isEmpty
                    ? null
                    : () => _export(items),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_rounded, size: 19),
                label: Text(_busy ? '正在导出…' : '导出 txt'),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent.withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 可点选的选项胶囊。
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
            color: selected
                ? accent.withValues(alpha: 0.2)
                : AppColors.card,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.inkSoft,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
    );
  }
}
