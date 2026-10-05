import 'dart:io';

import 'package:flutter/foundation.dart';

// single source of truth for platform adaptation across the ui
bool isTv = false;

final bool isDesktop =
    !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

bool get isWideLayout => isDesktop || isTv;
