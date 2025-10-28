import 'package:flutter/material.dart';

/// 🎨 Tema centralizado de la app EVENTOS EPIS – UPT.
/// Usa Material Design 3 y colores institucionales de la UPT.
ThemeData buildAppTheme() {
  const primaryColor = Color(0xFF002E6D); // Azul institucional UPT
  const secondaryColor = Color(0xFFFFC107); // Dorado institucional

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 1,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: secondaryColor,
      foregroundColor: Colors.black,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
    ),
    fontFamily: 'Poppins', // Fuente moderna
  );
}
