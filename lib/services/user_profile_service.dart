import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static const _keyUserName = 'user_name';
  static const _keyUserClass = 'user_class';

  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name.trim());
  }

  Future<void> setUserClass(String className) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserClass, className.trim());
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyUserName);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<String?> getUserClass() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyUserClass);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
