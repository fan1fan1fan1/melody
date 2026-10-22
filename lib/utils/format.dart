/// 把时长格式化。
///
/// 小于一小时时输出 `mm:ss`（如 `03:24`），
/// 大于等于一小时时输出 `h:mm:ss`（如 `1:05:09`）。
String formatDuration(Duration duration) {
  if (duration.inMilliseconds <= 0 || duration.isNegative) return '00:00';
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
