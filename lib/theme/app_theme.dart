import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1E1E1E); // Dark background
  static const Color secondaryColor =
      Color(0xFF333333); // Slightly lighter dark
  static const Color accentColor =
      Color(0xFFE040FB); // Purple accent for highlights
  static const Color backgroundColor =
      Color(0xFF121212); // Almost black background
  static const Color textColor = Colors.white;

  static ThemeData get theme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: primaryColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// class ButtonTheme {
//   static const Color primaryColor = Color(0xFF1E1E1E); // Dark background
//   static const Colors secondaryColor = ; // Slightly lighter dark
//   static const Color accentColor =
//       Color(0xFFE040FB); // Purple accent for highlights
//   static const Color backgroundColor =
//       Color(0xFF121212); // Almost black background
//   static const Color textColor = Colors.white;
// }

class SectionStyles {
  static TextStyle heading(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return GoogleFonts.playfairDisplay(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0.2,
      color: color ??
          (theme.brightness == Brightness.dark ? Colors.white : Colors.black87),
    );
  }
}
