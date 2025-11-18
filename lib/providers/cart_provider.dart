import 'package:flutter/material.dart';
import 'package:lustra_ai/models/jewellery.dart';

class CartProvider with ChangeNotifier {
  final Map<String, Jewellery> _items = {};

  Map<String, Jewellery> get items {
    return {..._items};
  }

  int get itemCount {
    return _items.length;
  }

  void addItem(Jewellery product) {
    if (product.id == null) return; // Cannot add product without an ID

    if (_items.containsKey(product.id)) {
      // if product is already in the cart, increase quantity
      _items.update(
        product.id!,
        (existingCartItem) => existingCartItem.copyWith(
          quantity: existingCartItem.quantity + 1,
        ),
      );
    } else {
      // add new product to cart
      _items.putIfAbsent(
        product.id!,
        () => product.copyWith(quantity: 1),
      );
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
