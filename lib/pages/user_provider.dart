import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  // Данные пользователя
  String? _userId;
  String? _userEmail;

  String? get userId => _userId;
  String? get userEmail => _userEmail;

  void setUserId(String userId) {
    _userId = userId;
    notifyListeners();
  }

  void setUserEmail(String email) {
    _userEmail = email;
    notifyListeners();
  }

  // Корзина: ключ - id товара, значение - количество
  final Map<int, int> _cart = {};

  Map<int, int> get cart => Map.unmodifiable(_cart);

  void addToCart(int itemId) {
    _cart[itemId] = (_cart[itemId] ?? 0) + 1;
    notifyListeners();
  }

  void removeFromCart(int itemId) {
    if (!_cart.containsKey(itemId)) return;

    if (_cart[itemId]! > 1) {
      _cart[itemId] = _cart[itemId]! - 1;
    } else {
      _cart.remove(itemId);
    }
    notifyListeners();
  }
}
