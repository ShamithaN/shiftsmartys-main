import 'package:flutter/material.dart';

Theme datePickerThemeBuilder(BuildContext context, Widget? child) {
  return Theme(
    data: Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF2A3243),
        primary: Color(0xFF34C8E8),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          color: Color(0xFF34C8E8),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    child: child!,
  );
}
