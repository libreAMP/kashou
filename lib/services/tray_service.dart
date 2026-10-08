import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener, WindowListener {
  TrayService._();
  static final TrayService instance = TrayService._();

  static bool get _supported => Platform.isLinux || Platform.isWindows;

  Future<void> initialize() async {
    if (!_supported) return;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);

    var trayReady = false;
    try {
      trayManager.addListener(this);
      final icon = _iconPath();
      if (icon != null) await trayManager.setIcon(icon);
      // the linux side of the plugin has no tooltip call
      if (Platform.isWindows) await trayManager.setToolTip('kashou');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'Show kashou'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ]));
      trayReady = true;
    } catch (e) {
      debugPrint('tray setup failed: $e');
    }

    // a hidden window with no tray icon showing would be unreachable
    final hasHost = Platform.isWindows || await _hasTrayHost();
    await windowManager.setPreventClose(trayReady && hasHost);
  }

  // linux needs a status notifier host before the icon is drawn at all
  Future<bool> _hasTrayHost() async {
    try {
      final result = await Process.run('gdbus', [
        'call',
        '--session',
        '--dest',
        'org.freedesktop.DBus',
        '--object-path',
        '/org/freedesktop/DBus',
        '--method',
        'org.freedesktop.DBus.NameHasOwner',
        'org.kde.StatusNotifierWatcher',
      ]);
      return result.stdout.toString().contains('true');
    } catch (_) {
      return false;
    }
  }

  String? _iconPath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final name = Platform.isWindows ? 'icon.ico' : 'icon.png';
    final file = File('$exeDir/data/flutter_assets/assets/icons/$name');
    return file.existsSync() ? file.path : null;
  }

  Future<void> _show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    if (Platform.isWindows) trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    if (Platform.isWindows) trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _show();
      case 'quit':
        _quit();
    }
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) await windowManager.hide();
  }
}
