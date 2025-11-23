import 'package:flutter/material.dart';

import 'screens/admin_scan_screen.dart';
import 'screens/log_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/student_main_screen.dart';
import 'services/user_service.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const NfcFieldLoggerApp());
}

class NfcFieldLoggerApp extends StatelessWidget {
  const NfcFieldLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC Field Logger',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: AppTheme.primaryBlue,
        scaffoldBackgroundColor: AppTheme.lightBackground,
        colorScheme: ColorScheme.light(
          primary: AppTheme.primaryBlue,
          secondary: AppTheme.primaryBlue,
          surface: Colors.white,
          background: AppTheme.lightBackground,
        ),
        fontFamily: AppTheme.fontFamily,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 1500));
    
    final userRole = await UserService.getUserRole();
    
    if (!mounted) return;
    
    Widget nextScreen;
    if (userRole == null) {
      nextScreen = const RoleSelectionScreen();
    } else if (userRole == UserRole.student) {
      nextScreen = const StudentMainScreen();
    } else {
      nextScreen = const MainScreen();
    }
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.contactless,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'NFC Field Logger',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Initializing...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<LogScreenState> _logScreenKey = GlobalKey<LogScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const AdminScanScreen(),
      LogScreen(key: _logScreenKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.contactless,
                  label: 'Scan',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _buildNavItem(
                  icon: Icons.description_outlined,
                  label: 'Log',
                  isSelected: _currentIndex == 1,
                  onTap: () {
                    setState(() => _currentIndex = 1);
                    // Refresh log screen when switching to it
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _logScreenKey.currentState?.refreshData();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color:
                    isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              if (isSelected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
