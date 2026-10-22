import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/media_item.dart';

/// 从系统文件选择器导入媒体文件。
class MediaImporter {
  const MediaImporter._();

  /// 与 MainActivity 通信的通道：申请权限 + 查询本机媒体。
  static const MethodChannel _channel = MethodChannel('meloday/media');

  /// 只有桌面平台才能可靠地拿到文件夹的真实路径。
  static bool get supportsFolderImport =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// 安卓可以直接扫描本机媒体库（不需要系统文件选择器）。
  static bool get supportsDeviceScan => Platform.isAndroid;

  /// 扫描电脑里常见的音乐 / 视频目录（桌面端的「扫描」入口）。
  static Future<List<String>> scanDesktop(MediaKind kind) async {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isEmpty) return <String>[];
    const names = <String>[
      'Music',
      'Videos',
      'Downloads',
      'Desktop',
      '音乐',
      '视频',
      '下载',
    ];
    final result = <String>[];
    for (final name in names) {
      final directory = Directory('$home${Platform.pathSeparator}$name');
      if (!await directory.exists()) continue;
      await _scan(directory, kind, result, 0);
    }
    return result;
  }

  /// 申请读取权限并列出手机里全部音频 / 视频的真实路径。
  ///
  /// 权限被拒绝或查询失败时抛出带说明的异常，交由调用方提示用户。
  static Future<List<String>> scanDevice(MediaKind kind) async {
    bool granted;
    try {
      granted =
          await _channel.invokeMethod<bool>('requestPermission', {
            'kind': kind.name,
          }) ??
          false;
    } on PlatformException catch (error) {
      throw '无法申请读取权限：${error.message ?? error.code}';
    }
    if (!granted) {
      throw '没有读取权限。请在系统设置里允许「Melody」访问音乐和视频后重试';
    }
    final paths = await _channel.invokeListMethod<String>('queryMediaPaths', {
      'kind': kind.name,
    });
    return paths ?? const <String>[];
  }

  static List<String> extensionsFor(MediaKind kind) {
    final extensions =
        (kind == MediaKind.audio ? kAudioExtensions : kVideoExtensions).toList();
    extensions.sort();
    return extensions;
  }

  /// 弹出文件选择器，返回可用的本地绝对路径。
  static Future<List<String>> pickFiles(MediaKind kind) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensionsFor(kind),
      dialogTitle: kind == MediaKind.audio ? '选择音频文件' : '选择视频文件',
    );
    final paths = <String>[];
    for (final file in picked) {
      final localPath = file.path;
      if (localPath != null && localPath.isNotEmpty) {
        paths.add(localPath);
        continue;
      }
      // Android 等平台可能返回 content:// 地址，先复制到应用目录再使用。
      final copied = await _copyIntoAppDir(file);
      if (copied != null) paths.add(copied);
    }
    return paths;
  }

  /// 选择一个文件夹并递归扫描其中的媒体文件。
  static Future<List<String>> pickFolder(MediaKind kind) async {
    final directoryPath =
        await FilePicker.getDirectoryPath(dialogTitle: '选择文件夹');
    if (directoryPath == null || directoryPath.isEmpty) return <String>[];
    final result = <String>[];
    await _scan(Directory(directoryPath), kind, result, 0);
    return result;
  }

  static Future<void> _scan(
    Directory directory,
    MediaKind kind,
    List<String> out,
    int depth,
  ) async {
    if (depth > 8) return;
    List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } catch (_) {
      return;
    }
    for (final entry in entries) {
      if (entry is File) {
        if (kindForExtension(MediaItem.extensionOf(entry.path)) == kind) {
          out.add(entry.path);
        }
      } else if (entry is Directory) {
        await _scan(entry, kind, out, depth + 1);
      }
    }
  }

  static Future<String?> _copyIntoAppDir(PlatformFile file) async {
    try {
      final base = await getApplicationSupportDirectory();
      final target = Directory('${base.path}${Platform.pathSeparator}media');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      final destination =
          File('${target.path}${Platform.pathSeparator}${file.name}');
      if (await destination.exists()) return destination.path;
      final sink = destination.openWrite();
      await sink.addStream(file.readAsByteStream());
      await sink.close();
      return destination.path;
    } catch (_) {
      return null;
    }
  }
}
