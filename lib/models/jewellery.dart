class Jewellery {
  final String name;
  final double weight;
  final String imagePath;
  final String type;
  final bool isAsset;
  final String price;
  final String? originalPrice;
  final String? discount;
  final bool isBestseller;

  Jewellery({
    required this.name,
    required this.weight,
    required this.imagePath,
    required this.type,
    required this.price,
    this.originalPrice,
    this.discount,
    this.isAsset = false,
    this.isBestseller = false,
  });
  
  // Convert from a Map (e.g., from Firestore) to a Jewellery object
  factory Jewellery.fromMap(Map<String, dynamic> map) {
    return Jewellery(
      name: map['name'] ?? '',
      weight: (map['weight'] ?? 0).toDouble(),
      imagePath: map['imagePath'] ?? '',
      type: map['type'] ?? '',
      price: map['price'] ?? '',
      originalPrice: map['originalPrice'],
      discount: map['discount'],
      isAsset: map['isAsset'] ?? false,
      isBestseller: map['isBestseller'] ?? false,
    );
  }
  
  // Convert a Jewellery object to a Map (e.g., to store in Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'weight': weight,
      'imagePath': imagePath,
      'type': type,
      'price': price,
      'originalPrice': originalPrice,
      'discount': discount,
      'isAsset': isAsset,
      'isBestseller': isBestseller,
    };
  }
}
