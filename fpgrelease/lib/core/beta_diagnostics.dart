import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';

/// Lightweight Open Beta diagnostics that works fully offline.
/// It records uncaught Flutter/platform errors locally so a tester can attach
/// the diagnostic file to a bug report. No personal data is collected here.
class BetaDiagnostics {
  static bool _installed = false;

  static Future<void> install() async {
    if (_installed) return;
    _installed = true;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(record(
        type: 'flutter_error',
        message: details.exceptionAsString(),
        stack: details.stack?.toString(),
      ));
    };

    ui.PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(record(
        type: 'platform_error',
        message: error.toString(),
        stack: stack.toString(),
      ));
      return true;
    };
  }

  static Future<void> record({
    required String type,
    required String message,
    String? stack,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fpg_beta_diagnostics.jsonl');
      final row = jsonEncode({
        'time': DateTime.now().toUtc().toIso8601String(),
        'type': type,
        'message': message.length > 4000 ? message.substring(0, 4000) : message,
        'stack': stack == null ? null : (stack.length > 8000 ? stack.substring(0, 8000) : stack),
      });
      await file.writeAsString('$row\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Diagnostics must never crash the game.
    }
  }

  static Future<File?> file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/fpg_beta_diagnostics.jsonl');
      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }
}
