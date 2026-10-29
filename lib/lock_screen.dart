import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'sms_parser.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

/// Covers the whole app until the 4-digit PIN is entered.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({required this.state, required this.onUnlock, super.key});

  final AppState state;
  final VoidCallback onUnlock;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String entered = '';
  bool wrong = false;

  void _digit(String digit) {
    if (entered.length >= 4) return;
    setState(() {
      entered += digit;
      wrong = false;
    });
    if (entered.length < 4) return;
    if (widget.state.checkPin(entered)) {
      widget.onUnlock();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        wrong = true;
        entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = widget.state.language;
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => SizedBox(
          width: 76,
          height: 76,
          child: TextButton(
            style: TextButton.styleFrom(shape: const CircleBorder()),
            onPressed: onTap ?? () => _digit(label),
            child: child ?? Text(label, style: theme.textTheme.headlineMedium),
          ),
        );
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40, color: BirrColors.forest),
              const SizedBox(height: 12),
              Text('BirrWise', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(t(lang, 'pinEnter'), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              Semantics(
                label: '${entered.length} / 4',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < entered.length
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          border: Border.all(color: theme.colorScheme.primary),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 32,
                child: wrong
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          t(lang, 'pinWrong'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.error),
                        ),
                      )
                    : null,
              ),
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final digit in row) key(digit)],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 76),
                  key('0'),
                  key(
                    '',
                    onTap: () => setState(() {
                      if (entered.isNotEmpty) {
                        entered = entered.substring(0, entered.length - 1);
                      }
                    }),
                    child: Icon(Icons.backspace_outlined,
                        semanticLabel: t(lang, 'delete')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First-run welcome: language choice and the privacy promise.
Future<void> showWelcome(BuildContext context, AppState state) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final lang = state.language;
          final theme = Theme.of(context);
          return AlertDialog(
            icon: const Icon(Icons.spa_outlined, color: BirrColors.forest),
            title: Text(t(lang, 'welcomeTitle')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(lang, 'welcomeSubtitle')),
                  const SizedBox(height: 18),
                  Text(t(lang, 'chooseLanguage'),
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'am', label: Text('አማርኛ')),
                    ],
                    selected: {lang},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        state.setLanguage(value.first),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: BirrColors.forest),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t(lang, 'privacyFirstHeading'),
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(t(lang, 'privacyFirstBody'),
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t(lang, 'smsPermissionContinue')),
              ),
            ],
          );
        },
      ),
    );

/// Asks which banks and wallets are the person's. Alerts from the others are
/// ignored, and anything BirrWise already added from them is taken out.
Future<void> showBankPicker(BuildContext context, AppState state) async {
  final counts = state.alertCounts;
  final mine = state.banksChosen
      ? {
          for (final i in SmsParser.institutions)
            if (!state.ignoredInstitutions.contains(i)) i
        }
      : {
          for (final a in state.accounts)
            if (SmsParser.institutions.contains(a.institution)) a.institution
        };
  final chosen = await showDialog<Set<String>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final lang = state.language;
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(t(lang, 'banksTitle')),
          contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(t(lang, 'banksBody'),
                      style: theme.textTheme.bodySmall),
                ),
                for (final institution in SmsParser.institutions)
                  CheckboxListTile(
                    secondary: InstitutionBadge(institution, radius: 18),
                    title: Text(institution),
                    subtitle: counts[institution] == null
                        ? null
                        : Text(tf(lang, 'alertsFound',
                            {'count': counts[institution]!})),
                    value: mine.contains(institution),
                    onChanged: (value) => setDialogState(() => value == true
                        ? mine.add(institution)
                        : mine.remove(institution)),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, mine),
              child: Text(t(lang, 'done')),
            ),
          ],
        );
      },
    ),
  );
  if (chosen != null) await state.chooseBanks(chosen);
}
