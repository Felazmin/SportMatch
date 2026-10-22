import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DesignAsset extends StatelessWidget {
  const DesignAsset(
    this.file, {
    super.key,
    this.folder = 'auth',
    this.size = 18,
    this.color,
  });
  final String file;
  final String folder;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/$folder/$file.svg',
    width: size,
    height: size,
    colorFilter: color == null
        ? null
        : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

class AppColors {
  static const green = Color(0xFF00A859);
  static const darkGreen = Color(0xFF007D43);
  static const background = Color(0xFFF4F6F8);
  static const ink = Color(0xFF1A1D20);
  static const muted = Color(0xFF6C757D);
  static const faint = Color(0xFFA3AEB9);
  static const border = Color(0xFFE9ECEF);
}

class FigmaIcon extends StatelessWidget {
  const FigmaIcon(this.file, {super.key, this.size = 22, this.color});
  final String file;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    const rasterIcons = {
      '70656',
      'ae34c',
      '8c511',
      '96aba',
      'd96ab',
      '54444',
      'ec335',
    };
    if (rasterIcons.contains(file)) {
      final foreground =
          color ??
          switch (file) {
            '70656' => AppColors.green,
            '54444' => Colors.white,
            'ec335' => AppColors.muted,
            _ => AppColors.faint,
          };
      final originalRed = switch (file) {
        '70656' => 0.0,
        'ec335' => 108.0,
        _ => 163.0,
      };
      final factor = file == '54444' ? 1.0 : -255 / (255 - originalRed);
      final bias = file == '54444' ? 0.0 : 255 * 255 / (255 - originalRed);
      // These Figma exports include the parent fill; retain only the icon mask.
      return ClipRect(
        child: SizedBox(
          width: size,
          height: size,
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix([
              0,
              0,
              0,
              0,
              foreground.r * 255,
              0,
              0,
              0,
              0,
              foreground.g * 255,
              0,
              0,
              0,
              0,
              foreground.b * 255,
              factor,
              0,
              0,
              0,
              bias,
            ]),
            child: Image.asset(
              'assets/figma/$file.png',
              width: size,
              height: size,
            ),
          ),
        ),
      );
    }
    return SvgPicture.asset(
      'assets/figma/$file.svg',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
