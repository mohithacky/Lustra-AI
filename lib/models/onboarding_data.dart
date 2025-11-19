import 'dart:io';

import 'package:lustra_ai/screens/theme_selection_screen.dart';

class OnboardingData {
  OnboardingData({
    this.shopName,
    this.shopAddress,
    this.phoneNumber,
    this.logoFile,
    this.instagramId,
    Map<String, String>? userCategories,
    Map<String, String>? userCollections,
    this.selectedTheme = WebsiteTheme.light,
    List<String>? productTypes,
  })  : userCategories = userCategories ?? {},
        userCollections = userCollections ?? {},
        productTypes = productTypes ?? [];
  final String? shopName;
  final String? shopAddress;
  final String? phoneNumber;
  final File? logoFile;
  final String? instagramId;
  final Map<String, String> userCategories;
  final Map<String, String> userCollections;
  final WebsiteTheme selectedTheme;
  final List<String> productTypes;

  OnboardingData copyWith({
    String? shopName,
    String? shopAddress,
    String? phoneNumber,
    File? logoFile,
    String? instagramId,
    Map<String, String>? userCategories,
    Map<String, String>? userCollections,
    WebsiteTheme? selectedTheme,
    List<String>? productTypes,
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
      productTypes: productTypes ?? this.productTypes,
    );
  }
}
