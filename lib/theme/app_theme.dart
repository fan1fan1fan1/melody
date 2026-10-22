import 'package:flutter/material.dart';

/// Melody 的配色与主题：深夜底色 + 霓虹紫粉青，卡片半透明。
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF9B5CFF);
  static const Color accent = Color(0xFFFF4FA3);

  /// 主文字（浅色）。
  static const Color ink = Color(0xFFF1EEFA);

  /// 次要文字。
  static const Color inkSoft = Color(0xFF9E99B8);

  static const Color line = Color(0x24FF6FD8);

  /// 视频模块的强调色（取自图标里的青色）。
  static const Color videoAccent = Color(0xFF3FE0FF);

  /// 白噪音模块的强调色（与底部导航的白噪音一致）。
  static const Color noise = Color(0xFF6EE7C4);

  /// 半透明卡面（霓虹描边 + 极淡底色，不遮挡背景）。
  static const Color card = Color(0x14FFFFFF);
  static const Color cardStrong = Color(0x24FFFFFF);
  static const Color cardBorder = Color(0x1FFFFFFF);

  /// 磨砂条 / 弹窗用的深色玻璃底色。
  static const Color glass = Color(0xB80D0B16);
  static const Color sheet = Color(0xF01A1730);

  /// 音乐（mp3）模块的渐变：粉紫。
  static const LinearGradient audioGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF4FA3), Color(0xFF8B4DFF)],
  );

  /// 视频（mp4）模块的渐变：青蓝。
  static const LinearGradient videoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3DD6F5), Color(0xFF4C6FFF)],
  );

  /// 品牌渐变。
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B4DFF), Color(0xFFFF4FA3)],
  );

  /// 音乐光碟的霓虹外圈颜色。
  static const List<Color> audioRim = [
    Color(0xFFFF4FA3),
    Color(0xFF8B4DFF),
    Color(0xFF35D3E8),
  ];

  /// 视频光碟的霓虹外圈颜色。
  static const List<Color> videoRim = [
    Color(0xFF35D3E8),
    Color(0xFF4C6FFF),
    Color(0xFFFF4FA3),
  ];

  /// 页面背景渐变：近黑底，带一点紫与洋红的暗调。
  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF07060D), Color(0xFF120E24), Color(0xFF180A1D)],
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF12101F));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: const Color(0xFF12101F),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: const TextTheme(
        titleMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: AppColors.ink, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.inkSoft, fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
        thumbColor: Colors.white,
        overlayColor: AppColors.primary.withValues(alpha: 0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.sheet,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: AppColors.inkSoft, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkSoft,
        textColor: AppColors.ink,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xF01A1730),
        contentTextStyle: TextStyle(color: AppColors.ink),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xF01A1730),
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: AppColors.ink, fontSize: 14),
      ),
    );
  }
}
