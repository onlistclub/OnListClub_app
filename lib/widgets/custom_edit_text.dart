import 'package:flutter/material.dart';

import '../core/app_export.dart';

/**
 * CustomEditText is a flexible text input component that supports various input types
 * including email, password, and general text input with proper validation and styling.
 * 
 * @param placeholder - Hint text displayed when the field is empty
 * @param inputType - Type of input (EMAIL, PASSWORD, TEXT) for keyboard and validation
 * @param passwordField - Whether this field should obscure text (for passwords)
 * @param validator - Custom validation function
 * @param controller - Text editing controller
 * @param onChanged - Callback when text changes
 * @param onTap - Callback when field is tapped
 * @param keyboardType - Custom keyboard type override
 * @param enabled - Whether the field is enabled for input
 * @param maxLines - Maximum number of lines (default 1)
 * @param textStyle - Custom text style
 * @param fillColor - Background fill color
 * @param borderColor - Border color
 * @param focusedBorderColor - Border color when focused
 * @param borderRadius - Border radius value
 * @param contentPadding - Internal padding
 * @param margin - External margin
 */
class CustomEditText extends StatefulWidget {
  const CustomEditText({
    Key? key,
    this.placeholder,
    this.inputType,
    this.passwordField,
    this.validator,
    this.controller,
    this.onChanged,
    this.onTap,
    this.keyboardType,
    this.enabled,
    this.maxLines,
    this.textStyle,
    this.fillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.borderRadius,
    this.contentPadding,
    this.margin,
  }) : super(key: key);

  /// Hint text displayed when the field is empty
  final String? placeholder;

  /// Type of input for keyboard and validation behavior
  final String? inputType;

  /// Whether this field should obscure text (for passwords)
  final bool? passwordField;

  /// Custom validation function
  final String? Function(String?)? validator;

  /// Text editing controller
  final TextEditingController? controller;

  /// Callback when text changes
  final void Function(String)? onChanged;

  /// Callback when field is tapped
  final void Function()? onTap;

  /// Custom keyboard type override
  final TextInputType? keyboardType;

  /// Whether the field is enabled for input
  final bool? enabled;

  /// Maximum number of lines
  final int? maxLines;

  /// Custom text style
  final TextStyle? textStyle;

  /// Background fill color
  final Color? fillColor;

  /// Border color
  final Color? borderColor;

  /// Border color when focused
  final Color? focusedBorderColor;

  /// Border radius value
  final double? borderRadius;

  /// Internal padding
  final EdgeInsets? contentPadding;

  /// External margin
  final EdgeInsets? margin;

  @override
  State<CustomEditText> createState() => _CustomEditTextState();
}

class _CustomEditTextState extends State<CustomEditText> {
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.passwordField ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        enabled: widget.enabled ?? true,
        maxLines: widget.maxLines ?? 1,
        obscureText: _obscureText,
        keyboardType: _getKeyboardType(),
        style: widget.textStyle ??
            TextStyleHelper.instance.title16ExtraBoldSFCompact
                .copyWith(color: appTheme.whiteCustom, height: 20.h / 16.fSize),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyleHelper.instance.title16ExtraBoldSFCompact
              .copyWith(
                  color: appTheme.whiteCustom.withAlpha(153),
                  height: 20.h / 16.fSize),
          filled: true,
          fillColor: widget.fillColor ?? appTheme.transparentCustom,
          contentPadding: widget.contentPadding ??
              EdgeInsets.only(
                top: 12.h,
                right: 12.h,
                bottom: widget.inputType == 'PASSWORD' ? 12.h : 8.h,
                left: 12.h,
              ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.h),
            borderSide: BorderSide(
              color: widget.borderColor ?? appTheme.greyCustom,
              width: 1.h,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.h),
            borderSide: BorderSide(
              color: widget.borderColor ?? appTheme.greyCustom,
              width: 1.h,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.h),
            borderSide: BorderSide(
              color: widget.focusedBorderColor ?? appTheme.blueCustom,
              width: 1.h,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.h),
            borderSide: BorderSide(
              color: appTheme.redCustom,
              width: 1.h,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 8.h),
            borderSide: BorderSide(
              color: appTheme.redCustom,
              width: 1.h,
            ),
          ),
          suffixIcon:
              widget.passwordField == true ? _buildPasswordToggle() : null,
        ),
      ),
    );
  }

  /// Determines the appropriate keyboard type based on input type
  TextInputType _getKeyboardType() {
    if (widget.keyboardType != null) {
      return widget.keyboardType!;
    }

    switch (widget.inputType?.toUpperCase()) {
      case 'EMAIL':
        return TextInputType.emailAddress;
      case 'PASSWORD':
        return TextInputType.visiblePassword;
      case 'PHONE':
        return TextInputType.phone;
      case 'NUMBER':
        return TextInputType.number;
      case 'URL':
        return TextInputType.url;
      default:
        return TextInputType.text;
    }
  }

  /// Builds the password visibility toggle button
  Widget _buildPasswordToggle() {
    return IconButton(
      icon: Icon(
        _obscureText ? Icons.visibility_off : Icons.visibility,
        color: appTheme.whiteCustom.withAlpha(153),
        size: 20.h,
      ),
      onPressed: () {
        setState(() {
          _obscureText = !_obscureText;
        });
      },
    );
  }
}
