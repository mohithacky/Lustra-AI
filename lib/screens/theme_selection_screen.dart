import 'package:flutter/material.dart';
import 'package:lustra_ai/models/onboarding_data.dart';

enum WebsiteTheme { light, dark }

class ThemeSelectionScreen extends StatefulWidget {
  final OnboardingData onboardingData;
  final Function(OnboardingData) onDataChanged;

  const ThemeSelectionScreen({
    super.key,
    required this.onboardingData,
    required this.onDataChanged,
  });

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Choose Your Theme',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF121212),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Select a theme for your website to match your brand’s identity.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildThemeOption(
                  context,
                  theme: WebsiteTheme.light,
                  label: 'Light Mode',
                  icon: Icons.wb_sunny_rounded,
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                ),
                _buildThemeOption(
                  context,
                  theme: WebsiteTheme.dark,
                  label: 'Dark Mode',
                  icon: Icons.nightlight_round,
                  backgroundColor: const Color(0xFF121212),
                  textColor: Colors.white,
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    {
      required WebsiteTheme theme,
      required String label,
      required IconData icon,
      required Color backgroundColor,
      required Color textColor,
    }
  ) {
    final isSelected = widget.onboardingData.selectedTheme == theme;

    return GestureDetector(
      onTap: () {
        widget.onDataChanged(widget.onboardingData.copyWith(selectedTheme: theme));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        height: 180,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: const Color(0xFFB5893B), width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: textColor),
            const SizedBox(height: 16),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
