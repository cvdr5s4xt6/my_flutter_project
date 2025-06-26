import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
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
}
