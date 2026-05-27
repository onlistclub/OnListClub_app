/// Theme e palette colori dell'app.
///
/// Espone `appTheme` (colori brand) e `theme` (`ThemeData` per `MaterialApp`).
/// I valori canonici sono dichiarati in `.claude/CLAUDE.md` — questo file è la
/// loro implementazione Dart. Non aggiungere colori non presenti lì.
library;

import 'package:flutter/material.dart';

LightCodeColors get appTheme => ThemeHelper().themeColor();
ThemeData get theme => ThemeHelper().themeData();

/// Helper class for managing themes and colors.

// ignore_for_file: must_be_immutable
class ThemeHelper {
  // The current app theme
  var _appTheme = "lightCode";

  // A map of custom color themes supported by the app
  Map<String, LightCodeColors> _supportedCustomColor = {
    'lightCode': LightCodeColors()
  };

  // A map of color schemes supported by the app
  Map<String, ColorScheme> _supportedColorScheme = {
    'lightCode': ColorSchemes.lightCodeColorScheme
  };

  /// Returns the lightCode colors for the current theme.
  LightCodeColors _getThemeColors() {
    return _supportedCustomColor[_appTheme] ?? LightCodeColors();
  }

  /// Returns the current theme data.
  ThemeData _getThemeData() {
    var colorScheme =
        _supportedColorScheme[_appTheme] ?? ColorSchemes.lightCodeColorScheme;
    return ThemeData(
      visualDensity: VisualDensity.standard,
      colorScheme: colorScheme,
    );
  }

  /// Returns the lightCode colors for the current theme.
  LightCodeColors themeColor() => _getThemeColors();

  /// Returns the current theme data.
  ThemeData themeData() => _getThemeData();
}

class ColorSchemes {
  static final lightCodeColorScheme = ColorScheme.light();
}

class LightCodeColors {
  // App Colors
  Color get white_A700 => Color(0xFFFFFFFF);
  Color get black_900 => Color(0xFF000000);
  Color get deep_purple_900 => Color(0xFF1600BC);
  Color get indigo_900 => Color(0xFF090050);
  Color get black_900_01 => Color(0xFF04002A);
  Color get red_900 => Color(0xFFB71C1C);

  // Additional Colors
  Color get transparentCustom => Colors.transparent;
  Color get whiteCustom => Colors.white;
  Color get greyCustom => Colors.grey;
  Color get blueCustom => Colors.blue;
  Color get redCustom => Colors.red;

  // Color Shades - Each shade has its own dedicated constant
  Color get grey200 => Colors.grey.shade200;
  Color get grey100 => Colors.grey.shade100;

  // New Colors
  Color get white_99 => Color(0x99FFFFFF);
  Color get blue_purple_A700 => Color(0xFF1D00FF);
  Color get purple_A700 => Color(0xFF1900D8);
  Color get deep_purple_A700 => Color(0xFF110099);
  Color get white_7F => Color(0x7FFFFFFF);
  Color get grey_888 => Color(0xFF888888);
}
