import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  Map<String, dynamic> _userProfile = {};

  Map<String, dynamic> get userProfile => _userProfile;

  void setUserProfile(Map<String, dynamic> profile) {
    print("UserProvider setUserProfile called with: $profile");
    _userProfile = profile; 
    notifyListeners();
  }

  void clearUserProfile() { 
    _userProfile = {}; 
    notifyListeners();
  }
}
