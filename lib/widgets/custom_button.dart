import 'package:flutter/material.dart';

import '../core/app_export.dart';

/**
 * CustomButton - A flexible and reusable button component
 * 
 * This widget provides a customizable button with support for:
 * - Custom text and styling
 * - Configurable background colors and borders
 * - Flexible padding and margin options
 * - Responsive design using SizeUtils
 * - Material Design principles with ElevatedButton base
 * 
 * @param text - The button text to display
 * @param onPressed - Callback function when button is pressed
 * @param backgroundColor - Background color of the button
 * @param textColor - Color of the button text
 * @param borderRadius - Border radius for rounded corners
 * @param padding - Internal padding of the button
 * @param margin - External margin around the button
 * @param fontSize - Font size of the button text
 * @param fontWeight - Font weight of the button text
 * @param fontFamily - Font family for the button text
 * @param width - Optional fixed width for the button
 * @param height - Optional fixed height for the button
 */
class CustomButton extends StatelessWidget {
  CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
    this.padding,
    this.margin,
    this.fontSize,
    this.fontWeight,
    this.fontFamily,
    this.width,
    this.height,
  }) : super(key: key);

  /// The text to display on the button
  final String text;

  /// Callback function triggered when button is pressed
  final VoidCallback? onPressed;

  /// Background color of the button
  final Color? backgroundColor;

  /// Color of the button text
  final Color? textColor;

  /// Border radius for rounded corners
  final double? borderRadius;

  /// Internal padding of the button
  final EdgeInsets? padding;

  /// External margin around the button
  final EdgeInsets? margin;

  /// Font size of the button text
  final double? fontSize;

  /// Font weight of the button text
  final FontWeight? fontWeight;

  /// Font family for the button text
  final String? fontFamily;

  /// Optional fixed width for the button
  final double? width;

  /// Optional fixed height for the button
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 26.h,
      margin: margin ?? EdgeInsets.zero,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Color(0xFFFFFFFF),
          foregroundColor: textColor ?? Color(0xFF000000),
          elevation: 0,
          shadowColor: appTheme.transparentCustom,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 10.h),
          ),
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: 30.h,
                vertical: 2.h,
              ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          text,
          style: TextStyleHelper.instance.textStyle4
              .copyWith(color: textColor ?? Color(0xFF000000)),
        ),
      ),
    );
  }
}
