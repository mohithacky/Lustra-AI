import 'dart:io';

import 'package:lustra_ai/screens/theme_selection_screen.dart';

class OnboardingData {
  OnboardingData({
    this.shopName,
    this.shopAddress,
    this.phoneNumber,
    this.logoFile,
    this.instagramId,
    List<String>? userCategories,
    List<String>? userCollections,
    this.selectedTheme = WebsiteTheme.light,
  })  : userCategories = userCategories ?? [],
        userCollections = userCollections ?? [];
  final String? shopName;
  final String? shopAddress;
  final String? phoneNumber;
  final File? logoFile;
  final String? instagramId;
  final List<String> userCategories;
  final List<String> userCollections;
  final WebsiteTheme selectedTheme;

  OnboardingData copyWith({
    String? shopName,
    String? shopAddress,
    String? phoneNumber,
    File? logoFile,
    String? instagramId,
    List<String>? userCategories,
    List<String>? userCollections,
    WebsiteTheme? selectedTheme,
  }) {
    return OnboardingData(
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      logoFile: logoFile ?? this.logoFile,
      instagramId: instagramId ?? this.instagramId,
      userCategories: userCategories ?? this.userCategories,
      userCollections: userCollections ?? this.userCollections,
      selectedTheme: selectedTheme ?? this.selectedTheme,
    );
  }
}
