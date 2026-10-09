import 'package:flutter/material.dart';

/// Tipografía incluida con la app: no solicita fuentes a internet.
class AppFonts {
  static TextStyle inter(
          {Color? color,
          double? fontSize,
          FontWeight? fontWeight,
          FontStyle? fontStyle,
          double? letterSpacing,
          double? height,
          TextDecoration? decoration,
          Color? decorationColor,
          List<Shadow>? shadows}) =>
      TextStyle(
          fontFamily: 'AppRoboto',
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          letterSpacing: letterSpacing,
          height: height,
          decoration: decoration,
          decorationColor: decorationColor,
          shadows: shadows);
  static TextTheme interTextTheme() =>
      ThemeData.light().textTheme.apply(fontFamily: 'AppRoboto');
}
