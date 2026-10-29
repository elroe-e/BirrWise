import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'dialogs.dart';
import 'domain.dart';
import 'strings.dart';
import 'widgets.dart';

/// Lists accounts with their derived balances. Each one can be corrected to
/// match the bank (recorded as an adjustment) or archived.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final lang = state.language;
          final ordered = [
            ...state.accounts.where((a) => !a.archived),
            ...state.accounts.where((a) => a.archived),
          ];
          return Scaffold(
            appBar: AppBar(title: Text(t(lang, 'accounts'))),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => showAddAccountDialog(context, state),
              icon: const Icon(Icons.add),
              label: Text(t(lang, 'addAccount')),
            ),
            body: ordered.isEmpty
                ? EmptyState(
                    title: t(lang, 'accounts'),
                    message: t(lang, 'noAccounts'),
                    action: t(lang, 'addAccount'),
                    onAction: () => showAddAccountDialog(context, state),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
                    children: [
                      for (final account in ordered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AccountTile(account: account, state: state),
                        ),
                    ],
                  ),
          );
        },
      );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.state});

  final Account account;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final lang = state.language;
    final theme = Theme.of(context);
    return BirrCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          InstitutionBadge(account.institution),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium),
                Text(
                  [
                    account.institution,
                    if (account.maskedNumber.isNotEmpty)
                      '•• ${account.maskedNumber}',
                    if (account.archived) t(lang, 'archived'),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  formatEtb(state.balanceFor(account.id),
                      hidden: state.hideBalances),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontFamily: 'serif',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'correct' => _showCorrectBalance(context),
              _ => state.setAccountArchived(account.id, !account.archived),
            },
            itemBuilder: (context) => [
              if (!account.archived)
                PopupMenuItem(
                  value: 'correct',
                  child: Text(t(lang, 'correctBalance')),
                ),
              PopupMenuItem(
                value: 'archive',
                child: Text(
                    t(lang, account.archived ? 'unarchive' : 'archive')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCorrectBalance(BuildContext context) async {
    final lang = state.language;
    final balance = state.balanceFor(account.id);
    final controller = TextEditingController(
      text: balance < 0
          ? ''
          : formatEtb(balance, withCode: false).replaceAll(',', ''),
    );
    String? error;
    final corrected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t(lang, 'correctBalance')} · ${account.name}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(t(lang, 'correctBalanceHint'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration: InputDecoration(
                  labelText: t(lang, 'currentBalance'),
                  prefixText: 'ETB  ',
                  errorText: error,
                ),
                onChanged: (_) => setSheetState(() => error = null),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    final value = parseEtbToSantim(controller.text);
                    if (value == null) {
                      setSheetState(() => error = t(lang, 'invalidAmount'));
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: Text(t(lang, 'save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (corrected == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final difference = await state.reconcileAccount(account.id, corrected);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(t(
            lang, difference == 0 ? 'balanceMatches' : 'balanceCorrected')),
      ));
  }
}
