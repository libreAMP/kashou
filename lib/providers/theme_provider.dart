import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// most saturated pixel makes a livelier seed than a plain average
Future<Color?> dominantColor(Uint8List bytes) async {
  try {
    final codec =
        await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData();
    if (data == null) return null;
    Color best = Colors.grey;
    var bestScore = -1.0;
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      final r = data.getUint8(i) / 255;
      final g = data.getUint8(i + 1) / 255;
      final b = data.getUint8(i + 2) / 255;
      final max = [r, g, b].reduce((a, c) => a > c ? a : c);
      final min = [r, g, b].reduce((a, c) => a < c ? a : c);
      final sat = max == 0 ? 0 : (max - min) / max;
      final score = sat * max;
      if (score > bestScore) {
        bestScore = score;
        best = Color.fromARGB(255, data.getUint8(i), data.getUint8(i + 1),
            data.getUint8(i + 2));
      }
    }
    return best;
  } catch (_) {
    return null;
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _useMaterialYou = true;
  String _themeSource = 'system';
  Color _accentColor = Colors.deepPurple;
  Color? _artSeed;
  bool _isLoaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get useMaterialYou => _themeSource == 'system';
  String get themeSource => _themeSource;
  Color get accentColor => _accentColor;
  Color? get artSeed => _artSeed;
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
      _useMaterialYou = prefs.getBool('use_material_you') ?? true;
      _themeSource =
          prefs.getString('theme_source') ?? (_useMaterialYou ? 'system' : 'accent');
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
    setThemeSource(value ? 'system' : 'accent');
  }

  Future<void> setThemeSource(String source) async {
    _themeSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_source', source);
    await prefs.setBool('use_material_you', source == 'system');
    notifyListeners();
  }

  void setArtSeed(Color? color) {
    _artSeed = color;
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', color.value);
    notifyListeners();
  }
}
