import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true; // Default to dark mode as per the current design
  bool _initialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _initialized;

  ThemeProvider() {
    _initializeTheme();
  }

  Future<void> _initializeTheme() async {
    await _loadThemeFromPrefs();
    _initialized = true;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemeToPrefs();
    notifyListeners();
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
      notifyListeners();
    } catch (e) {
      // If SharedPreferences fails, continue with default (dark mode)
      debugPrint('Error loading theme preferences: $e');
      _isDarkMode = true;
      notifyListeners();
    }
  }

  Future<void> _saveThemeToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      // If saving fails, at least print the error
      debugPrint('Error saving theme preferences: $e');
    }
  }

  ThemeData getTheme() {
    // Safely return the appropriate theme
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  // This ensures the app has a valid theme even before SharedPreferences initializes
  static ThemeData get initialTheme => _darkTheme;

  // Dark theme settings based on the reports page
  static final _darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.white70,
      surface: Color(0xFF1C1C1E), // Very dark grey surface color
    ),
    cardColor: const Color(0xFF1C1C1E),
    dividerColor: Colors.grey[800],
    buttonTheme: ButtonThemeData(
      buttonColor: Colors.grey[700],
      textTheme: ButtonTextTheme.primary,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        foregroundColor: Colors.white,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.black,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white60,
    ),
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(color: Colors.white, fontSize: 15),
      labelMedium: TextStyle(color: Colors.white70, fontSize: 14),
    ),
    useMaterial3: true,
  );

  // Light theme settings - contrast to dark theme
  static final _lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
    ),
    colorScheme: ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blue.shade700,
      surface: Colors.grey[100]!, // Light grey surface color
    ),
    cardColor: Colors.white,
    dividerColor: Colors.grey[300],
    buttonTheme: const ButtonThemeData(
      buttonColor: Colors.blue,
      textTheme: ButtonTextTheme.primary,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.blue.shade700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        foregroundColor: Colors.blue.shade700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey[600],
    ),
    textTheme: const TextTheme(
      titleMedium: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(color: Colors.black87, fontSize: 15),
      labelMedium: TextStyle(color: Colors.black54, fontSize: 14),
    ),
    useMaterial3: true,
  );
}
