import 'package:flutter/material.dart';

extension ColorContrast on Color {
  /// Returns black or white text color for readable contrast on this background.
  /// Uses WCAG AA threshold: luminance ≤ 0.179 → white text, > 0.179 → black text.
  /// This ensures minimum 4.5:1 contrast ratio for normal text.
  Color get contrastTextColor {
    return computeLuminance() <= 0.179 ? Colors.white : Colors.black;
  }
}
