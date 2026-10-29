import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accounts_screen.dart';
import 'app_state.dart';
import 'device.dart';
import 'dialogs.dart';
import 'domain.dart';
import 'lock_screen.dart';
import 'sms_automation.dart';
import 'sms_parser.dart';
import 'sms_inbox_screen.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class HubScreen extends StatelessWidget {
  const HubScreen({required this.state, required this.onInbox, super.key});

  final AppState state;
  final VoidCallback onInbox;

  @override
  Widget build(BuildContext context) {
    final lang = state.language;
    final tiles = [
      _HubItem(Icons.mark_email_unread_outlined, t(lang, 'inbox'),
          lang == 'am' ? 'የባንክ መልዕክቶችን ክለሳ' : 'Review bank messages',
          badge: state.pendingCount == 0 ? null : '${state.pendingCount}',
          onTap: onInbox),
      _HubItem(
        Icons.swap_horiz_rounded,
        t(lang, 'transfer'),
        lang == 'am' ? 'በራስዎ ሂሳቦች መካከል' : 'Between your own accounts',
        onTap: () => showAddEntrySheet(
          context,
          state,
          initialType: EntryType.transferOut,
        ),
      ),
      _HubItem(
        Icons.account_balance_wallet_outlined,
        t(lang, 'accounts'),
        t(lang, 'manageAccounts'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AccountsScreen(state: state)),
        ),
      ),
      _HubItem(
        Icons.file_download_outlined,
        lang == 'am' ? 'ውጭ ላክ' : 'Export CSV',
        t(lang, 'csvSub'),
        onTap: () => _saveCsv(context),
      ),
      _HubItem(
        Icons.backup_outlined,
        t(lang, 'backup'),
        t(lang, 'backupSub'),
        onTap: () => _backup(context),
      ),
      _HubItem(
        Icons.help_outline,
        lang == 'am' ? 'እገዛ' : 'Help',
        lang == 'am' ? 'ስለ ግላዊነት እና ኤስኤምኤስ' : 'Privacy and SMS tips',
        onTap: () => _helpInfo(context),
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 104),
      children: [
        Text(t(lang, 'tools'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 150,
          ),
          itemBuilder: (context, index) {
            final item = tiles[index];
            return BirrCard(
              onTap: item.onTap,
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      const Spacer(),
                      if (item.badge != null)
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          child: Text(item.badge!,
                              style: Theme.of(context).textTheme.labelSmall),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(item.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        BirrCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SwitchListTile(
            secondary: const Icon(Icons.storefront_outlined),
            title: Text(t(lang, 'merchantMode')),
            subtitle: Text(t(lang, 'merchantModeSub')),
            value: state.merchantMode,
            onChanged: (value) => state.setPreference('merchant', value),
          ),
        ),
        const SizedBox(height: 12),
        BirrCard(
          onTap: () => showPrivacyPolicy(context, lang),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: BirrColors.forest),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(lang, 'privacy'),
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(t(lang, 'privacySub'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveCsv(BuildContext context) async {
    final csv =
        StringBuffer('date,account,type,category,description,amount_etb,business\n');
    String quoted(String value) => '"${value.replaceAll('"', '""')}"';
    for (final entry in state.recentEntries) {
      final account = state.accounts
              .where((a) => a.id == entry.accountId)
              .firstOrNull
              ?.name ??
          '';
      final signed = switch (entry.type) {
        EntryType.income || EntryType.transferIn => entry.amount,
        EntryType.adjustment => entry.amount,
        _ => -entry.amount,
      };
      // Plain ASCII number (no grouping, '-' sign) so spreadsheets parse it.
      final amount = '${signed < 0 ? '-' : ''}${signed.abs() ~/ 100}.'
          '${(signed.abs() % 100).toString().padLeft(2, '0')}';
      csv.writeln(
        '${entry.date.toIso8601String()},${quoted(account)},${entry.type.name},'
        '${entry.category},${quoted(entry.party)},$amount,${entry.business}',
      );
    }
    await _saveFile(
      context,
      name: 'BirrWise_Transactions_${_today()}.csv',
      mimeType: 'text/csv',
      content: csv.toString(),
    );
  }

  Future<void> _backup(BuildContext context) async {
    final lang = state.language;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: Text(t(lang, 'saveBackup')),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: Text(t(lang, 'restoreBackup')),
              onTap: () => Navigator.pop(context, 'restore'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(t(lang, 'backupWarning'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'save') {
      await _saveFile(
        context,
        name: 'BirrWise_Backup_${_today()}.json',
        mimeType: 'application/json',
        content: state.exportBackup(),
      );
    } else if (choice == 'restore') {
      await _restore(context);
    }
  }

  Future<void> _restore(BuildContext context) async {
    final lang = state.language;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(lang, 'restoreBackup')),
        content: Text(t(lang, 'restoreConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t(lang, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(lang, 'restoreBackup')),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final content = await openDocument();
      if (content == null) return;
      message = t(lang,
          await state.restoreBackup(content) ? 'restoreDone' : 'restoreInvalid');
    } on PlatformException {
      message = t(lang, 'fileFailed');
    } on MissingPluginException {
      message = t(lang, 'fileFailed');
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveFile(
    BuildContext context, {
    required String name,
    required String mimeType,
    required String content,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      if (!await saveDocument(
          name: name, mimeType: mimeType, content: content)) {
        return;
      }
      message = t(state.language, 'fileSaved');
    } on PlatformException {
      message = t(state.language, 'fileFailed');
    } on MissingPluginException {
      message = t(state.language, 'fileFailed');
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  void _helpInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(state.language == 'am' ? 'የኤስኤምኤስ ግላዊነት' : 'SMS privacy'),
        content: Text(state.language == 'am'
            ? 'የባንክ መልዕክቶችዎን ሳያከማቹ የሚመርጡትን ብቻ ወደ የግብይት መዝገብ ያክሉ።'
            : 'Automatic bank-SMS tracking is optional. When enabled, only supported bank senders are checked on this device. Each clear alert is added automatically to the account for its bank, which BirrWise creates if needed, and the account follows the balance the bank reports. Unclear alerts, or alerts for a bank with several accounts, wait in review. New alerts sync when you reopen BirrWise. Nothing is sent to a server.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _HubItem {
  const _HubItem(this.icon, this.title, this.subtitle,
      {this.badge, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final lang = state.language;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
      children: [
        Text(t(lang, 'settingsTitle'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        _SettingsGroup(
          title: t(lang, 'language'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'am', label: Text('አማርኛ')),
              ],
              selected: {lang},
              showSelectedIcon: false,
              onSelectionChanged: (value) => state.setLanguage(value.first),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: t(lang, 'appearance'),
          children: [
            _SettingsSwitch(
              icon: Icons.dark_mode_outlined,
              title: t(lang, 'darkMode'),
              value: state.darkMode,
              onChanged: (value) => state.setPreference('dark', value),
            ),
            _SettingsSwitch(
              icon: Icons.visibility_off_outlined,
              title: t(lang, 'hideBalances'),
              value: state.hideBalances,
              onChanged: (value) => state.setPreference('hide', value),
            ),
            _SettingsSwitch(
              icon: Icons.calendar_month_outlined,
              title: t(lang, 'ethiopianCalendar'),
              value: state.useEthiopianCalendar,
              subtitle: lang == 'am'
                  ? 'ቀኖች በኢትዮጵያ አቆጣጠር ይታያሉ'
                  : 'Dates and monthly summaries use Ethiopian months',
              onChanged: (value) => state.setPreference('ethiopian', value),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: lang == 'am' ? 'ድምፅ እና ንዝረት' : 'Sound and haptics',
          children: [
            _SettingsSwitch(
              icon: Icons.volume_up_outlined,
              title: t(lang, 'sound'),
              value: state.soundEnabled,
              onChanged: (value) => state.setPreference('sound', value),
            ),
            _SettingsSwitch(
              icon: Icons.vibration,
              title: t(lang, 'haptics'),
              value: state.hapticsEnabled,
              onChanged: (value) => state.setPreference('haptics', value),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final (sound, icon, label) in [
                    ('chime', Icons.music_note_outlined, 'testChime'),
                    ('sms', Icons.notifications_outlined, 'testSms'),
                    ('cash', Icons.payments_outlined, 'testCash'),
                    ('goal', Icons.celebration_outlined, 'testGoal'),
                  ])
                    OutlinedButton.icon(
                      onPressed: state.soundEnabled
                          ? () => playSound(state, sound)
                          : null,
                      icon: Icon(icon),
                      label: Text(t(lang, label)),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: lang == 'am' ? 'ራስ-ሰር ክትትል' : 'Bank SMS automation',
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.sms_outlined),
              title: Text(t(lang, 'bankSmsAutomation')),
              subtitle: Text(t(lang, 'bankSmsAutomationSub')),
              value: state.bankSmsAutomationEnabled,
              onChanged: (enabled) =>
                  unawaited(_setBankSmsAutomation(context, state, enabled)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _smsAutomationStatus(state),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!state.smsHistoryScanned &&
                      state.bankSmsAutomationEnabled) ...[
                    const SizedBox(height: 6),
                    Text(
                      t(lang, 'smsHistoryOnce'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (state.lastSmsIngestSummary case final summary?
                      when state.bankSmsAutomationEnabled &&
                          state.smsAutomationStatus == 'ready') ...[
                    const SizedBox(height: 6),
                    Text(
                      summary.scanned == 0
                          ? t(lang, 'smsNoBankSenders')
                          : t(lang, 'smsImportSummary')
                              .replaceAll('{scanned}', '${summary.scanned}')
                              .replaceAll(
                                  '{recognized}', '${summary.recognized}')
                              .replaceAll('{imported}', '${summary.imported}')
                              .replaceAll('{pending}', '${summary.pending}')
                              .replaceAll('{ignored}', '${summary.ignored}')
                              .replaceAll(
                                  '{duplicates}', '${summary.duplicates}'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (state.smsAutomationError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      state.smsAutomationError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.account_balance_outlined),
                    title: Text(t(lang, 'monitoredBanks')),
                    subtitle: Text(t(lang, 'monitoredBanksCount').replaceAll(
                        '{count}',
                        '${SmsParser.institutions.where((i) => !state.ignoredInstitutions.contains(i)).length}')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showBankPicker(context, state),
                  ),
                  if (state.bankSmsAutomationEnabled) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () =>
                            unawaited(_scanBankSmsAgain(context, state)),
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text(t(lang, 'smsScanNow')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: lang == 'am' ? 'የኤስኤምኤስ ግላዊነት' : 'Detection',
          child: ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.sms_outlined),
            title: Text(lang == 'am' ? 'መልዕክት ለመሞከር' : 'Paste a bank SMS'),
            subtitle: Text(lang == 'am'
                ? 'ከመልዕክት መተግበሪያ በእጅ ይለጥፉ'
                : 'Paste a transaction message manually'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showImportSmsDialog(context, state),
          ),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: t(lang, 'security'),
          child: ListTile(
            minTileHeight: 64,
            leading: const Icon(Icons.pin_outlined),
            title: Text(t(lang, 'pinLock')),
            subtitle: Text(t(lang, state.hasPin ? 'pinOn' : 'pinOff')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => state.hasPin
                ? _removePin(context, state)
                : _setPin(context, state),
          ),
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: lang == 'am' ? 'ውሂብ' : 'Data',
          children: [
            ListTile(
              minTileHeight: 64,
              leading: const Icon(Icons.lock_outline),
              title: Text(t(lang, 'privacyPolicy')),
              subtitle: Text(t(lang, 'privacySub')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showPrivacyPolicy(context, lang),
            ),
            ListTile(
              minTileHeight: 64,
              leading: Icon(Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: Text(t(lang, 'eraseAll'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => _eraseAll(context, state),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'BirrWise',
            applicationVersion: '1.2.0',
            applicationLegalese: 'Private, offline-first finance tracking.',
          ),
          child: Text(
            'BirrWise · 1.2.0',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

String _smsAutomationStatus(AppState state) {
  final key = switch (state.smsAutomationStatus) {
    'permission_missing' => 'smsPermissionMissing',
    'sync_failed' => 'smsSyncFailed',
    'android_only' => 'smsAndroidOnly',
    'scanning' => 'smsScanning',
    'ready' => 'smsAutomationReady',
    _ => state.bankSmsAutomationEnabled
        ? 'smsAutomationReady'
        : 'smsAutomationOff',
  };
  return t(state.language, key);
}

Future<void> _scanBankSmsAgain(
  BuildContext context,
  AppState state,
) async {
  final succeeded =
      await SmsAutomationService().synchronize(state, rescanHistory: true);
  if (!context.mounted) return;
  final summary = state.lastSmsIngestSummary;
  final message = !succeeded
      ? t(state.language, 'smsSyncFailed')
      : summary == null
          ? t(state.language, 'smsAutomationReady')
          : summary.scanned == 0
              ? t(state.language, 'smsNoBankSenders')
              : t(state.language, 'smsImportSummary')
                  .replaceAll('{scanned}', '${summary.scanned}')
                  .replaceAll('{recognized}', '${summary.recognized}')
                  .replaceAll('{imported}', '${summary.imported}')
                  .replaceAll('{pending}', '${summary.pending}')
                  .replaceAll('{ignored}', '${summary.ignored}')
                  .replaceAll('{duplicates}', '${summary.duplicates}');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _setBankSmsAutomation(
  BuildContext context,
  AppState state,
  bool enabled,
) async {
  final service = SmsAutomationService();
  if (!enabled) {
    if (!await service.disable(state) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(state.language, 'smsSyncFailed'))),
      );
    }
    return;
  }
  await service.requestEnable(context, state);
}

Future<void> _setPin(BuildContext context, AppState state) async {
  final lang = state.language;
  final first = TextEditingController();
  final again = TextEditingController();
  Widget field(TextEditingController controller, String label,
          {String? error}) =>
      TextField(
        controller: controller,
        autofocus: controller == first,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, errorText: error),
      );
  // Asked twice: a mistyped PIN can only be undone by erasing everything.
  final pin = await showDialog<String>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: Listenable.merge([first, again]),
      builder: (context, _) {
        final complete = first.text.length == 4 && again.text.length == 4;
        final matches = complete && first.text == again.text;
        return AlertDialog(
          title: Text(t(lang, 'pinLock')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(first, t(lang, 'pinEnter')),
              field(again, t(lang, 'pinAgain'),
                  error: complete && !matches ? t(lang, 'pinMismatch') : null),
              Text(t(lang, 'pinForgetWarning'),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t(lang, 'cancel')),
            ),
            FilledButton(
              onPressed:
                  matches ? () => Navigator.pop(context, first.text) : null,
              child: Text(t(lang, 'save')),
            ),
          ],
        );
      },
    ),
  );
  first.dispose();
  again.dispose();
  if (pin != null) await state.setPin(pin);
}

Future<void> _removePin(BuildContext context, AppState state) async {
  final lang = state.language;
  final off = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t(lang, 'pinLock')),
      content: Text(t(lang, 'pinRemoveConfirm')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t(lang, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(t(lang, 'turnOff')),
        ),
      ],
    ),
  );
  if (off == true) await state.clearPin();
}

Future<void> _eraseAll(BuildContext context, AppState state) async {
  final lang = state.language;
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(t(lang, 'eraseAll')),
      content: Text(t(lang, 'eraseConfirm')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t(lang, 'cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: Text(t(lang, 'eraseEverything')),
        ),
      ],
    ),
  );
  if (sure != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  // Stop the Android receiver first, or its queued alerts come back in.
  if (!await SmsAutomationService().disable(state)) {
    messenger.showSnackBar(
        SnackBar(content: Text(t(state.language, 'smsSyncFailed'))));
    return;
  }
  await state.clearAllData();
  messenger.showSnackBar(SnackBar(content: Text(t(state.language, 'erased'))));
}

/// What BirrWise does with SMS and money data, in plain words.
void showPrivacyPolicy(BuildContext context, String lang) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t(lang, 'privacyPolicy')),
      content: SingleChildScrollView(child: Text(t(lang, 'privacyPolicyBody'))),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(lang, 'understood')),
        ),
      ],
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, this.children, this.child});

  final String title;
  final List<Widget>? children;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: child ??
                Column(
                  children: children ?? const [],
                ),
          ),
        ],
      );
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: onChanged,
        minTileHeight: 56,
      );
}
