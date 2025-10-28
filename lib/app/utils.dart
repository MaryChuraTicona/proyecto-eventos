import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const colorPrimary = Color(0xFF0F2A4A); // azul institucional
  const colorSecondary = Color(0xFFC9A227); // dorado
  const surface = Color(0xFFF7F7F9);

  final scheme = ColorScheme.fromSeed(
    seedColor: colorPrimary,
    primary: colorPrimary,
    secondary: colorSecondary,
    surface: surface,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: surface,
    fontFamily: 'Poppins',
  );
}
