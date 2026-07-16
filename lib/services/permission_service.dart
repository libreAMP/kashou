import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class PermissionService {
  static Future<void> initialize() async {
  }

  static Future<bool> requestPermissions() async {
    try {
      List<Permission> permissions = [];

      if (Platform.isAndroid) {
        permissions.add(Permission.audio);
      }

      permissions.add(Permission.notification);
      permissions.add(Permission.bluetoothConnect);

      // Request permissions but don't fail if denied
      await permissions.request();

      // pre android 13 the media permission is plain storage
      if (Platform.isAndroid && !await Permission.audio.isGranted) {
        await Permission.storage.request();
      }

      // Always return true to allow app to proceed
      return true;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return true; // Allow app to proceed even on error
    }
  }

  static Future<bool> checkStoragePermission() async {
    if (await Permission.audio.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }

    var status = await Permission.audio.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  static Future<bool> checkNotificationPermission() async {
    if (await Permission.notification.isGranted) {
      return true;
    }

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> checkBluetoothPermission() async {
    if (await Permission.bluetoothConnect.isGranted) {
      return true;
    }

    final status = await Permission.bluetoothConnect.request();
    return status.isGranted;
  }
}
