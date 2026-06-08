import 'package:flutter/material.dart';

class AppTheme {
  // Colores de la marca GlamourML (Paleta Premium de Maquillaje y Belleza)
  static const Color primaryColor = Color(0xFFD4AF37); // Oro Premium
  static const Color accentColor = Color(0xFFE07A5F);  // Rosa Melocotón Vibrante
  static const Color deepRose = Color(0xFFC94A70);     // Rosa Profundo / Labial
  static const Color darkBg = Color(0xFF121212);       // Fondo Oscuro Elegante
  static const Color cardBg = Color(0xFF1E1E1E);       // Fondo de Tarjeta Oscuro
  static const Color surfaceColor = Color(0xFF1A1A1A);  // Superficies
  static const Color textPrimary = Color(0xFFF5F5F5);   // Texto Principal Claro
  static const Color textSecondary = Color(0xFFB0B0B0); // Texto Secundario

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: deepRose,
        secondary: primaryColor,
        tertiary: accentColor,
        background: Color(0xFFFFF9FA), // Fondo rosa sumamente sutil y cálido
        surface: Colors.white,
        error: Color(0xFFD32F2F),
      ),
      scaffoldBackgroundColor: const Color(0xFFFFF9FA),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: deepRose.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: deepRose),
        titleTextStyle: TextStyle(
          color: deepRose,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: 'PlayfairDisplay', // Se puede mapear a fuentes del sistema
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: deepRose,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: deepRose, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
    );
  }
}
