import 'dart:io';

import 'package:flutter/services.dart';

import 'app_state.dart';

const _channel = MethodChannel('birrwise/sms');

/// Plays a synthesized sound: "chime", "sms", "goal" or "cash". Falls back to
/// the system click where the Android player is unavailable.
Future<void> playSound(AppState state, String name) async {
  if (!state.soundEnabled) return;
  try {
    if (Platform.isAndroid &&
        await _channel.invokeMethod<bool>('playSound', {'name': name}) ==
            true) {
      return;
    }
  } on PlatformException {
    // Fall through to the system click.
  } on MissingPluginException {
    // Fall through to the system click.
  }
  await SystemSound.play(SystemSoundType.click);
}

/// True while Android's file picker is in front, so leaving the app for it
/// does not trigger the PIN lock.
bool filePickerOpen = false;

/// Asks where to save [content]. Returns false if the person cancelled.
Future<bool> saveDocument({
  required String name,
  required String mimeType,
  required String content,
}) =>
    _picking(() async =>
        await _channel.invokeMethod<bool>('saveDocument', {
          'name': name,
          'mimeType': mimeType,
          'content': content,
        }) ==
        true);

/// Asks for a file and returns its text, or null if the person cancelled.
Future<String?> openDocument() =>
    _picking(() => _channel.invokeMethod<String>('openDocument'));

Future<T> _picking<T>(Future<T> Function() action) async {
  filePickerOpen = true;
  try {
    return await action();
  } finally {
    filePickerOpen = false;
  }
}
