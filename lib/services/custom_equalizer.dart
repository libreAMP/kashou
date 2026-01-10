import 'package:flutter/services.dart';

class CustomEqualizer {
  static const MethodChannel _channel =
      MethodChannel('com.libreamp.kashou/equalizer');

  static Future<void> init(int sessionId) async {
    await _channel.invokeMethod('initEqualizer', {'sessionId': sessionId});
  }

  static Future<void> setBandLevel(int bandId, int level) async {
    await _channel
        .invokeMethod('setBandLevel', {'bandId': bandId, 'level': level});
  }

  static Future<List<int>> getBandLevelRange() async {
    final result = await _channel.invokeMethod('getBandLevelRange');
    return (result as List<dynamic>).cast<int>();
  }

  static Future<List<int>> getCenterBandFreqs() async {
    final result = await _channel.invokeMethod('getCenterBandFreqs');
    return (result as List<dynamic>).cast<int>();
  }

  static Future<List<String>> getPresetNames() async {
    final result = await _channel.invokeMethod('getPresetNames');
    return (result as List<dynamic>).cast<String>();
  }

  static Future<void> setPreset(String presetName) async {
    await _channel.invokeMethod('setPreset', {'presetName': presetName});
  }

  static Future<List<double>> getPresetBandLevels() async {
    final result = await _channel.invokeMethod('getPresetBandLevels');
    return (result as List<dynamic>).cast<double>();
  }

  static Future<void> setBassBoost(int strength) async {
    await _channel.invokeMethod('setBassBoost', {'strength': strength});
  }

  static Future<void> setVirtualizer(int strength) async {
    await _channel.invokeMethod('setVirtualizer', {'strength': strength});
  }

  static Future<void> enableEffects(bool enabled) async {
    await _channel.invokeMethod('enableEffects', {'enabled': enabled});
  }

  static Future<void> release() async {
    await _channel.invokeMethod('releaseEqualizer');
  }
}
