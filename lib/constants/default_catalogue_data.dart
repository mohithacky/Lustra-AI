// Default website and catalogue categories and subcategories
// Centralized so onboarding, catalogue, and website can share the same data.

const Map<String, String> kDefaultWebsiteCategories = {
  'Earrings':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fearrings.png?alt=media&token=039ba275-b8ad-4368-a676-e644d7a14714',
  'Bracelet':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fbracelet.png?alt=media&token=f56e2f20-7579-41c2-91f1-afdf43598069',
  'Pendant':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fpendant.png?alt=media&token=89e8067a-97f6-4d90-b840-348b9f8f63c1',
  'Choker':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fchoker.png?alt=media&token=6b3146df-e5d0-49ba-9ed5-f94372823152',
  'Ring':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fring.png?alt=media&token=b608cae4-1074-41c9-9faa-600fc650405f',
  'Bangles':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fbangles.png?alt=media&token=27026318-b6d7-45b0-a874-c19f5ff3b0c8',
  'Necklace':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fnecklace.png?alt=media&token=a2724d3a-0770-438d-afa2-9c80879337a3',
  'Long Necklace':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Flong_necklace.png?alt=media&token=7302794e-dc33-4f81-b61e-bdb3bdfa66ed',
  'Mangtika':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fmangtika.png?alt=media&token=0ed19735-f836-41c3-a9a5-8f13642264cb',
  'Mangalsutra Pendant':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fmangalsutra_pendant.png?alt=media&token=8343a491-b746-4841-b653-99c8b1ae09fc',
  'Chain':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fchain.png?alt=media&token=773911da-fba0-4213-9836-b0bab1cc702b',
  'Dholna':
      'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fdholna.png?alt=media&token=e53076d4-64d2-425f-9b9d-0ad0436cb6ce',
};

// Default catalogue subcategories per category. These mirror the hardcoded
// defaults that were previously only in the catalogue screen.
const Map<String, List<String>> kDefaultCatalogueSubcategories = {
  'Earrings': ['Studs', 'Hoops', 'Jhumkas', 'Drops', 'Daily wear'],
  'Chain': ['Light chains', 'Heavy chains', 'Daily wear', 'Kids'],
  'Ring': ['Solitaire', 'Bands', 'Couple rings', 'Cocktail'],
  'Bracelet': ['Tennis', 'Kada', 'Charm', 'Daily wear'],
  'Pendant': ['Solitaire', 'Initials', 'Heart', 'Religious'],
  'Bangles': ['Gold bangles', 'Designer bangles', 'Daily wear', 'Bridal'],
  'Necklace': ['Short', 'Long', 'Bridal', 'Daily wear'],
  'Long Necklace': ['Layered', 'Temple', 'Bridal', 'Daily wear'],
  'Mangtika': ['Simple', 'Bridal', 'Designer'],
  'Mangalsutra Pendant': ['Daily wear', 'Traditional', 'Designer'],
  'Dholna': ['Traditional', 'Bridal', 'Daily wear'],
};
