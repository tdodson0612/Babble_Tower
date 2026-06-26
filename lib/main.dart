// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/services/hive_service.dart';
import 'data/services/prefs_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise storage before anything else touches it
  await HiveService.init();
  await PrefsService.init();

  runApp(
    const ProviderScope(
      child: BabbleTowerApp(),
    ),
  );
}