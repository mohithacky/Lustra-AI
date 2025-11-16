import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LuxuryTheme {
  // Colors
  static const Color offWhite = Color(0xFFF8F7F4);
  static const Color gold = Color(0xFFC5A572);
  static const Color black = Color(0xFF121212);
  static const Color grey = Colors.grey;

  // Gradients
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD9C08D),
      Color(0xFFC5A572),
      Color(0xFFAD8B5C),
    ],
  );

  // Text Theme
  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.playfairDisplay(
      fontSize: 40,
      fontWeight: FontWeight.bold,
      color: black,
      letterSpacing: 0.4,
    ),
    headlineMedium: GoogleFonts.playfairDisplay(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: black,
    ),
    bodyLarge: GoogleFonts.lato(
      fontSize: 16,
      height: 1.45,
      color: black,
    ),
    bodyMedium: GoogleFonts.lato(
      fontSize: 14,
      height: 1.35,
      color: black,
    ),
    labelLarge: GoogleFonts.lato(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      letterSpacing: 0.4,
    ),
  );

  // Card Decoration
  static BoxDecoration premiumCard({bool elevated = false}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ]
          : [],
    );
  }

  // Gold Button Style
  static ButtonStyle goldButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: gold,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  // Page Horizontal Padding
  static EdgeInsets pagePadding =
      const EdgeInsets.symmetric(horizontal: 20, vertical: 18);
}
