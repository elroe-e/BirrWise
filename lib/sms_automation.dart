import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'domain.dart';
import 'strings.dart';

class SmsAutomationService {
  static const _channel = MethodChannel('birrwise/sms');
  static bool _syncing = false;

  Future<bool> enable(AppState state) async {
    if (!Platform.isAndroid) {
      state.setSmsAutomationStatus('android_only');
      return false;
    }
    try {
      final permissions = await _channel.invokeMapMethod<String, bool>(
        'requestSmsPermissions',
      );
      if (permissions?['read'] != true || permissions?['receive'] != true) {
        state.setSmsAutomationStatus('permission_missing');
        return false;
      }
      await _setNativeEnabled(true);
      await state.setBankSmsAutomationEnabled(true);
      return await synchronize(state);
    } on PlatformException catch (error) {
      state.setSmsAutomationError('${error.code}: ${error.message ?? ''}');
      return false;
    } on MissingPluginException {
      state.setSmsAutomationError('The Android SMS bridge is unavailable.');
      return false;
    }
  }

  Future<bool> disable(AppState state) async {
    if (!Platform.isAndroid) {
      await state.setBankSmsAutomationEnabled(false);
      return true;
    }
    try {
      await _setNativeEnabled(false);
      await state.setBankSmsAutomationEnabled(false);
      return true;
    } on PlatformException catch (error) {
      state.setSmsAutomationError('${error.code}: ${error.message ?? ''}');
      return false;
    } on MissingPluginException {
      state.setSmsAutomationError('The Android SMS bridge is unavailable.');
      return false;
    }
  }

  Future<bool> synchronize(AppState state, {bool rescanHistory = false}) async {
    if (!Platform.isAndroid || !state.bankSmsAutomationEnabled) return false;
    if (_syncing) return true;
    _syncing = true;
    state.setSmsAutomationStatus('scanning');
    try {
      final permissions =
          await _channel.invokeMapMethod<String, bool>('smsPermissions');
      if (permissions?['read'] != true || permissions?['receive'] != true) {
        state.setSmsAutomationStatus('permission_missing');
        return false;
      }

      await _setNativeEnabled(true);
      final messages = <BankSms>[];
      if (rescanHistory || !state.smsHistoryScanned) {
        messages.addAll(await _readBankInbox());
      }
      final incoming = await _readIncomingBankSms();
      messages.addAll(incoming);

      final summary = await state.ingestBankSms(messages);
      if (!state.smsHistoryScanned) await state.markSmsHistoryScanned();
      await _clearIncomingBankSms(
          incoming.map((message) => message.id).toList());
      state.setSmsAutomationStatus('ready');
      state.setSmsAutomationSummary(summary);
      return true;
    } on PlatformException catch (error) {
      state.setSmsAutomationError('${error.code}: ${error.message ?? ''}');
      return false;
    } on FormatException catch (error) {
      state.setSmsAutomationError(error.message);
      return false;
    } on StateError catch (error) {
      state.setSmsAutomationError(error.message);
      return false;
    } on MissingPluginException {
      state.setSmsAutomationError('The Android SMS bridge is unavailable.');
      return false;
    } finally {
      _syncing = false;
    }
  }

  Future<bool> requestEnable(BuildContext context, AppState state) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.sms_outlined),
        title: Text(t(state.language, 'smsPermissionTitle')),
        content: Text(t(state.language, 'smsPermissionBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(state.language, 'dismiss')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(state.language, 'smsPermissionContinue')),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return false;

    final enabled = await enable(state);
    if (!context.mounted) return enabled;
    final message = enabled
        ? _scanResult(state)
        : t(
            state.language,
            switch (state.smsAutomationStatus) {
              'permission_missing' => 'smsPermissionMissing',
              'android_only' => 'smsAndroidOnly',
              _ => 'smsSyncFailed',
            });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return enabled;
  }

  static String _scanResult(AppState state) {
    final summary = state.lastSmsIngestSummary;
    if (summary == null) return t(state.language, 'smsAutomationReady');
    if (summary.scanned == 0) return t(state.language, 'smsNoBankSenders');
    return t(state.language, 'smsImportSummary')
        .replaceAll('{scanned}', '${summary.scanned}')
        .replaceAll('{recognized}', '${summary.recognized}')
        .replaceAll('{imported}', '${summary.imported}')
        .replaceAll('{pending}', '${summary.pending}')
        .replaceAll('{ignored}', '${summary.ignored}')
        .replaceAll('{duplicates}', '${summary.duplicates}');
  }

  Future<void> _setNativeEnabled(bool enabled) async {
    await _channel.invokeMethod<void>(
      'setSmsAutomationEnabled',
      {'enabled': enabled},
    );
  }

  Future<void> _clearIncomingBankSms(List<String> ids) async {
    await _channel.invokeMethod<void>(
      'clearIncomingBankSms',
      {'ids': ids},
    );
  }

  Future<List<BankSms>> _readBankInbox() async {
    final since = DateTime.now().subtract(smsHistoryWindow);
    final rows = await _channel.invokeListMethod<Object?>(
          'readBankInbox',
          {'sinceMillis': since.millisecondsSinceEpoch},
        ) ??
        const [];
    return rows.map(_decodeSms).toList();
  }

  Future<List<BankSms>> _readIncomingBankSms() async {
    final rows =
        await _channel.invokeListMethod<Object?>('readIncomingBankSms') ??
            const [];
    return rows.map(_decodeSms).toList();
  }

  BankSms _decodeSms(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Android returned an invalid SMS record.');
    }
    final id = value['id'];
    final sender = value['sender'];
    final body = value['body'];
    final receivedAt = value['receivedAt'];
    if (id is! String ||
        sender is! String ||
        body is! String ||
        receivedAt is! int) {
      throw const FormatException('Android returned an incomplete SMS record.');
    }
    return BankSms(
      id: id,
      sender: sender,
      body: body,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(receivedAt),
    );
  }
}
