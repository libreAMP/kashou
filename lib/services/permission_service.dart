import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class PermissionService {
  static Future<void> initialize() async {
    // Don't request permissions during initialization
    // They will be requested when needed
  }

  static Future<bool> requestPermissions() async {
    try {
      List<Permission> permissions = [];
      
      // Add audio permission for Android 13+
      if (Platform.isAndroid) {
        permissions.add(Permission.audio);
      }
      
      // Add notification permission (Android 13+)
      permissions.add(Permission.notification);
      
      // Add bluetooth permission (Android 12+)
      permissions.add(Permission.bluetoothConnect);

      Map<Permission, PermissionStatus> statuses = await permissions.request();

      bool allGranted = statuses.values.every((status) => 
        status.isGranted || status.isLimited
      );

      if (!allGranted) {
        debugPrint('Some permissions were not granted');
        // Log which permissions were denied
        statuses.forEach((permission, status) {
          if (!status.isGranted && !status.isLimited) {
            debugPrint('Permission denied: $permission - $status');
          }
        });
      }

      return allGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  static Future<bool> checkStoragePermission() async {
    if (await Permission.audio.isGranted) {
      return true;
    }

    final status = await Permission.audio.request();
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
