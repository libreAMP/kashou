import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  String _fontFamily = 'DM Sans';
  bool _enableGapless = true;
  bool _enableCrossfade = false;
  double _crossfadeDuration = 3.0;
  bool _enableReplayGain = false;
  bool _enableYouTubeIntegration = false;
  bool _enableCasting = true;
  bool _enableAndroidAuto = true;
  int _bufferSize = 2048;
  String _resamplerQuality = 'High';
  bool _enableDither = false;
  String _ytdlBaseUrl = 'https://ytdl-wrapper.onrender.com';
  bool _minimalBottomBar = false;
  bool _isLoaded = false;

  // Getters
  String get fontFamily => _fontFamily;
  bool get enableGapless => _enableGapless;
  bool get enableCrossfade => _enableCrossfade;
  double get crossfadeDuration => _crossfadeDuration;
  bool get enableReplayGain => _enableReplayGain;
  bool get enableYouTubeIntegration => _enableYouTubeIntegration;
  bool get enableCasting => _enableCasting;
  bool get enableAndroidAuto => _enableAndroidAuto;
  int get bufferSize => _bufferSize;
  String get resamplerQuality => _resamplerQuality;
  bool get enableDither => _enableDither;
  String get ytdlBaseUrl => _ytdlBaseUrl;
  bool get minimalBottomBar => _minimalBottomBar;
  bool get isLoaded => _isLoaded;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _fontFamily = prefs.getString('font_family') ?? 'System';
      _enableGapless = prefs.getBool('enable_gapless') ?? true;
      _enableCrossfade = prefs.getBool('enable_crossfade') ?? false;
      _crossfadeDuration = prefs.getDouble('crossfade_duration') ?? 3.0;
      _enableReplayGain = prefs.getBool('enable_replay_gain') ?? false;
      _enableYouTubeIntegration = prefs.getBool('enable_youtube') ?? true;
      _enableCasting = prefs.getBool('enable_casting') ?? true;
      _enableAndroidAuto = prefs.getBool('enable_android_auto') ?? true;
      _bufferSize = prefs.getInt('buffer_size') ?? 2048;
      _resamplerQuality = prefs.getString('resampler_quality') ?? 'High';
      _enableDither = prefs.getBool('enable_dither') ?? false;
      _ytdlBaseUrl = prefs.getString('ytdl_base_url') ?? 'https://ytdl-wrapper.onrender.com';
      _minimalBottomBar = prefs.getBool('minimal_bottom_bar') ?? false;
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error loading settings: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setFontFamily(String font) async {
    _fontFamily = font;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_family', font);
    notifyListeners();
  }

  Future<void> setEnableGapless(bool value) async {
    _enableGapless = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_gapless', value);
    notifyListeners();
  }

  Future<void> setEnableCrossfade(bool value) async {
    _enableCrossfade = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_crossfade', value);
    notifyListeners();
  }

  Future<void> setCrossfadeDuration(double value) async {
    _crossfadeDuration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('crossfade_duration', value);
    notifyListeners();
  }

  Future<void> setEnableReplayGain(bool value) async {
    _enableReplayGain = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_replay_gain', value);
    notifyListeners();
  }

  Future<void> setEnableYouTubeIntegration(bool value) async {
    _enableYouTubeIntegration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_youtube', value);
    notifyListeners();
  }

  Future<void> setEnableCasting(bool value) async {
    _enableCasting = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_casting', value);
    notifyListeners();
  }

  Future<void> setEnableAndroidAuto(bool value) async {
    _enableAndroidAuto = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_android_auto', value);
    notifyListeners();
  }

  Future<void> setBufferSize(int value) async {
    _bufferSize = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('buffer_size', value);
    notifyListeners();
  }

  Future<void> setResamplerQuality(String value) async {
    _resamplerQuality = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resampler_quality', value);
    notifyListeners();
  }

  Future<void> setEnableDither(bool value) async {
    _enableDither = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_dither', value);
    notifyListeners();
  }

  Future<void> setYtdlBaseUrl(String url) async {
    _ytdlBaseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ytdl_base_url', url);
    notifyListeners();
  }

  Future<void> setMinimalBottomBar(bool value) async {
    _minimalBottomBar = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('minimal_bottom_bar', value);
    notifyListeners();
  }
}
