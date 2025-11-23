import 'package:shared_preferences/shared_preferences.dart';

enum UserRole {
  student,
  admin,
}

class UserService {
  static const String _keyUserRole = 'user_role';

  static Future<void> setUserRole(UserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role.name);
  }

  static Future<UserRole?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleString = prefs.getString(_keyUserRole);
    
    if (roleString == null) return null;
    
    return UserRole.values.firstWhere(
      (role) => role.name == roleString,
      orElse: () => UserRole.student,
    );
  }

  static Future<void> clearUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserRole);
  }

  static Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == UserRole.admin;
  }

  static Future<bool> isStudent() async {
    final role = await getUserRole();
    return role == UserRole.student;
  }
}