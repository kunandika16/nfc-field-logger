import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';
import 'screens/log_screen.dart';
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
      home: const MainScreen(),
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
      const ScanScreen(),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
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
