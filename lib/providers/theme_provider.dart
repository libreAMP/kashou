import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _useMaterialYou = false;
  Color _accentColor = Colors.deepPurple;
  bool _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get useMaterialYou => _useMaterialYou;
  Color get accentColor => _accentColor;
  bool get isLoaded => _isLoaded;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
      _themeMode = themeModeIndex < ThemeMode.values.length 
          ? ThemeMode.values[themeModeIndex] 
          : ThemeMode.system;
      _useMaterialYou = prefs.getBool('use_material_you') ?? false;
      _accentColor = Color(
        prefs.getInt('accent_color') ?? Colors.deepPurple.value,
      );
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error loading theme preferences: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setUseMaterialYou(bool value) async {
    _useMaterialYou = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_material_you', value);
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.value);
    notifyListeners();
  }
}
