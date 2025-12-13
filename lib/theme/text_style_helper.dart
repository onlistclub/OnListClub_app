import 'package:flutter/material.dart';
import '../core/app_export.dart';

/// A helper class for managing text styles in the application
class TextStyleHelper {
  static TextStyleHelper? _instance;

  TextStyleHelper._();

  static TextStyleHelper get instance {
    _instance ??= TextStyleHelper._();
    return _instance!;
  }

  // Display Styles
  // Large text styles for prominent headings

  TextStyle get display40RegularTiltWarp => TextStyle(
        fontSize: 40.fSize,
        fontWeight: FontWeight.w400,
        fontFamily: 'Tilt Warp',
        color: appTheme.white_A700,
      );

  TextStyle get display36RegularTiltWarp => TextStyle(
        fontSize: 36.fSize,
        fontWeight: FontWeight.w400,
        fontFamily: 'Tilt Warp',
        color: appTheme.white_A700,
      );

  // Headline Styles
  // Medium-large text styles for section headers

  TextStyle get headline32ExtraBoldSFCompact => TextStyle(
        fontSize: 32.fSize,
        fontWeight: FontWeight.w800,
        fontFamily: 'SF Compact',
        color: appTheme.white_A700,
      );

  TextStyle get headline32RegularTiltWarp => TextStyle(
        fontSize: 32.fSize,
        fontWeight: FontWeight.w400,
        fontFamily: 'Tilt Warp',
        color: appTheme.white_A700,
      );

  // Title Styles
  // Medium text styles for titles and subtitles

  TextStyle get title20RegularRoboto => TextStyle(
        fontSize: 20.fSize,
        fontWeight: FontWeight.w400,
        fontFamily: 'Roboto',
      );

  TextStyle get title16ExtraBoldSFCompact => TextStyle(
        fontSize: 16.fSize,
        fontWeight: FontWeight.w800,
        fontFamily: 'SF Compact',
        color: appTheme.white_A700,
      );

  TextStyle get title16RegularTiltWarp => TextStyle(
        fontSize: 16.fSize,
        fontWeight: FontWeight.w400,
        fontFamily: 'Tilt Warp',
        color: appTheme.white_A700,
      );

  // Body Styles
  // Regular text styles for body content

  TextStyle get body14LightSFPro => TextStyle(
        fontSize: 14.fSize,
        fontWeight: FontWeight.w300,
        fontFamily: 'SF Pro',
        color: appTheme.white_A700,
      );

  // Label Styles
  // Small text styles for labels and captions

  TextStyle get label12RegularTiltWarp => TextStyle(
        fontSize: 12.fSize,
        fontWeight: FontWeight.w400,
        fontFamily: 'Tilt Warp',
        color: appTheme.white_A700,
      );

  // Other Styles
  // Miscellaneous text styles without specified font size

  TextStyle get textStyle4 => TextStyle();
}
