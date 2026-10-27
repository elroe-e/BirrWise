import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'dialogs.dart';
import 'domain.dart';
import 'ethiopian_date.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showImportSmsDialog(BuildContext context, AppState state) async {
  final sender = TextEditingController();
  final body = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                state.language == 'am'
                    ? 'የባንክ መልዕክት አስገባ'
                    : 'Review a bank SMS',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              state.language == 'am'
                  ? 'መልዕክቱ ከተሳሳተ የላኪ ስም ከሆነ አይቀበልም።'
                  : 'The sender must match a supported institution. Message text is stored only on this device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sender,
              decoration: InputDecoration(
                labelText: state.language == 'am' ? 'የላኪ ስም' : 'Sender ID',
                hintText: 'CBE',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText:
                    state.language == 'am' ? 'የመልዕክት ጽሑፍ' : 'Message text',
                hintText: 'You have paid ETB 450.00 to ...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () async {
                  final added = await state.ingestSms(sender.text, body.text);
                  if (!context.mounted) return;
                  if (added) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.language == 'am'
                            ? 'ለክለሳ ተጨምሯል'
                            : 'Message added to your review inbox'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.language == 'am'
                            ? 'መልዕክቱ አልተለየም ወይም ተደጋግሟል'
                            : 'Message not recognized, or already in your inbox'),
                      ),
                    );
                  }
                },
                child:
                    Text(state.language == 'am' ? 'ክለሳ ጀምር' : 'Review message'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  sender.dispose();
  body.dispose();
}

class SmsInboxScreen extends StatefulWidget {
  const SmsInboxScreen({required this.state, super.key});

  final AppState state;

  @override
  State<SmsInboxScreen> createState() => _SmsInboxScreenState();
}

class _SmsInboxScreenState extends State<SmsInboxScreen> {
  int selectedTab = 0;
  final expanded = <String>{};

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        // This screen is a pushed route, so it must listen for changes itself
        // (confirm, dismiss, background sync) to stay current.
        listenable: state,
        builder: (context, _) => _buildInbox(context),
      );

  Widget _buildInbox(BuildContext context) {
    final lang = state.language;
    const tabs = ['pending', 'confirmed', 'dismissed'];
    final currentStatus = tabs[selectedTab];
    final items = state.messages
        .where((message) => message.status == currentStatus)
        .toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final confirmAllCandidates = _confirmAllCandidates();
    int count(String status) =>
        state.messages.where((m) => m.status == status).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(t(lang, 'inbox')),
        actions: [
          IconButton(
            tooltip: lang == 'am' ? 'SMS አስገባ' : 'Paste SMS',
            onPressed: () => showImportSmsDialog(context, state),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < tabs.length; i++)
                  ButtonSegment(
                    value: i,
                    label: Text('${t(lang, tabs[i])} (${count(tabs[i])})'),
                  ),
              ],
              selected: {selectedTab},
              onSelectionChanged: (value) =>
                  setState(() => selectedTab = value.first),
              showSelectedIcon: false,
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    title: t(lang, 'nothingYet'),
                    message: t(lang, 'smsEmpty'),
                    action: lang == 'am' ? 'SMS አስገባ' : 'Paste a bank SMS',
                    onAction: () => showImportSmsDialog(context, state),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                    children: [
                      for (final message in items)
                        _SmsReviewCard(
                          // Keyed by message so edits made on one card never
                          // carry over to the next one after a confirm.
                          key: ValueKey(message.id),
                          message: message,
                          state: state,
                          expanded: expanded.contains(message.id),
                          onExpand: () => setState(() {
                            if (!expanded.add(message.id)) {
                              expanded.remove(message.id);
                            }
                          }),
                          onDismiss: () => _dismiss(context, message),
                        ),
                      if (currentStatus == 'pending' &&
                          confirmAllCandidates.length >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48)),
                            onPressed: () =>
                                _confirmAll(context, confirmAllCandidates),
                            icon: const Icon(Icons.done_all),
                            label: Text(
                                '${t(lang, 'confirmAll')} (${confirmAllCandidates.length})'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// High-confidence alerts that can safely be confirmed in one go: they
  /// match exactly one account and are not older than that account.
  List<(PendingSms, Account)> _confirmAllCandidates() {
    final result = <(PendingSms, Account)>[];
    for (final message in state.messages) {
      if (message.status != 'pending' ||
          message.confidence != SmsConfidence.high ||
          message.direction == SmsDirection.unknown) {
        continue;
      }
      final matches = state.accounts
          .where((a) =>
              !a.archived &&
              a.institution.toLowerCase() == message.institution.toLowerCase())
          .toList();
      if (matches.length != 1) continue;
      if (state.isOlderThanTracking(message, matches.single.id)) continue;
      result.add((message, matches.single));
    }
    return result;
  }

  Future<void> _confirmAll(
      BuildContext context, List<(PendingSms, Account)> candidates) async {
    final lang = state.language;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(lang, 'confirmAllTitle')),
        content:
            Text(tf(lang, 'confirmAllBody', {'count': candidates.length})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t(lang, 'cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t(lang, 'confirm'))),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;
    var confirmed = 0;
    for (final (message, account) in candidates) {
      if (await state.confirmSms(message.id, accountId: account.id)) {
        confirmed++;
      }
    }
    await confirmFeedback(state);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tf(lang, 'confirmAllDone', {'count': confirmed})),
      ));
  }

  Future<void> _dismiss(BuildContext context, PendingSms message) async {
    await state.updateSms(message.copyWith(status: 'dismissed'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(t(state.language, 'smsDismissedToast')),
        action: SnackBarAction(
          label: t(state.language, 'undo'),
          onPressed: () => _restore(message.id),
        ),
      ));
  }

  Future<void> _restore(String id) async {
    final current = state.messages.where((m) => m.id == id).firstOrNull;
    if (current == null || current.status != 'dismissed') return;
    await state.updateSms(current.copyWith(status: 'pending'));
  }
}

class _SmsReviewCard extends StatefulWidget {
  const _SmsReviewCard({
    required this.message,
    required this.state,
    required this.expanded,
    required this.onExpand,
    required this.onDismiss,
    super.key,
  });

  final PendingSms message;
  final AppState state;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onDismiss;

  @override
  State<_SmsReviewCard> createState() => _SmsReviewCardState();
}

class _SmsReviewCardState extends State<_SmsReviewCard> {
  late SmsDirection direction = widget.message.direction;
  late String party = widget.message.party;
  late String category = widget.message.category;
  String? chosenAccountId;
  bool busy = false;

  /// The chosen account if it still exists, else the account for this bank,
  /// else any active account. Resolved on every build so an account created
  /// from this card is picked up.
  String? get accountId {
    final active =
        widget.state.accounts.where((a) => !a.archived).toList();
    if (active.any((a) => a.id == chosenAccountId)) return chosenAccountId;
    return active
            .where((a) =>
                a.institution.toLowerCase() ==
                widget.message.institution.toLowerCase())
            .firstOrNull
            ?.id ??
        active.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final state = widget.state;
    final lang = state.language;
    final theme = Theme.of(context);
    final selectedAccountId = accountId;
    final activeAccounts = state.accounts.where((a) => !a.archived).toList();
    final pending = message.status == 'pending';
    final color = direction == SmsDirection.income
        ? BirrColors.income
        : direction == SmsDirection.expense
            ? BirrColors.expense
            : BirrColors.goldDeep;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: BirrCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    message.institution.substring(0, 1),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message.institution,
                          style: theme.textTheme.titleMedium),
                      Text(_receivedTime(message.receivedAt),
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusChip(
                  message.confidence == SmsConfidence.high
                      ? t(lang, 'high')
                      : t(lang, 'check'),
                  tone: message.confidence == SmsConfidence.high
                      ? ChipTone.success
                      : ChipTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 17),
            Text(
              '${direction == SmsDirection.income ? '+' : direction == SmsDirection.expense ? '−' : ''}${formatEtb(message.amount, hidden: state.hideBalances)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: 'serif',
                fontSize: 25,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (pending && message.direction == SmsDirection.unknown) ...[
              const SizedBox(height: 12),
              Text(
                  lang == 'am'
                      ? 'የግብይት አይነት ይምረጡ'
                      : 'Choose transaction direction',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 7),
              SegmentedButton<SmsDirection>(
                segments: [
                  ButtonSegment(
                      value: SmsDirection.income,
                      label: Text(t(lang, 'incomeDirection'))),
                  ButtonSegment(
                      value: SmsDirection.expense,
                      label: Text(t(lang, 'expenseDirection'))),
                ],
                selected: direction == SmsDirection.unknown ? {} : {direction},
                emptySelectionAllowed: true,
                onSelectionChanged: (value) {
                  if (value.isEmpty) return;
                  setState(() => direction = value.first);
                },
                showSelectedIcon: false,
              ),
            ],
            if (pending && activeAccounts.isNotEmpty) ...[
              const SizedBox(height: 13),
              DropdownButtonFormField<String>(
                // Rebuilt when the resolved account changes.
                key: ValueKey(selectedAccountId),
                initialValue: selectedAccountId,
                decoration: InputDecoration(
                    labelText: t(lang, 'account'), isDense: true),
                items: activeAccounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} · ${a.institution}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => chosenAccountId = value);
                },
              ),
              if (selectedAccountId != null &&
                  state.isOlderThanTracking(message, selectedAccountId)) ...[
                const SizedBox(height: 10),
                _OlderAlertNote(text: t(lang, 'olderThanTracking')),
              ],
              const SizedBox(height: 11),
              TextFormField(
                initialValue: party,
                decoration: InputDecoration(
                  labelText: t(lang, 'description'),
                  isDense: true,
                ),
                onChanged: (value) => party = value,
              ),
              const SizedBox(height: 11),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: t(lang, 'category'),
                  isDense: true,
                ),
                items: financeCategories.keys
                    .map((key) => DropdownMenuItem(
                          value: key,
                          child: Text(t(lang, key)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => category = value);
                },
              ),
            ],
            if (pending && activeAccounts.isEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48)),
                onPressed: () => showAddAccountDialog(context, state),
                icon: const Icon(Icons.add),
                label: Text(t(lang, 'addAccount')),
              ),
            ],
            const SizedBox(height: 7),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: widget.onExpand,
              icon:
                  Icon(widget.expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(t(lang, 'original')),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: widget.expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  state.hideBalances
                      ? (lang == 'am'
                          ? 'የቀሪ ሂሳብ ጽሑፍ እስኪታይ ድረስ ተደብቋል።'
                          : 'Message text is hidden while balances are hidden.')
                      : message.body,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
            if (pending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: busy ||
                          direction == SmsDirection.unknown ||
                          selectedAccountId == null
                      ? null
                      : () => _confirm(context, selectedAccountId),
                  child: Text(t(lang, 'confirm')),
                ),
              ),
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: busy ? null : widget.onDismiss,
                  child: Text(t(lang, 'dismiss')),
                ),
              ),
            ],
            if (message.status == 'dismissed')
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => state
                      .updateSms(message.copyWith(status: 'pending')),
                  icon: const Icon(Icons.undo),
                  label: Text(t(lang, 'restore')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, String accountId) async {
    final state = widget.state;
    final lang = state.language;
    final message = widget.message;
    // The card leaves the Pending list as soon as it is confirmed, so take the
    // app-level messenger now; this card's context will be unmounted.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    await state.updateSms(message.copyWith(
      direction: direction,
      party: party,
      category: category,
    ));
    final added = await state.confirmSms(message.id, accountId: accountId);
    if (added) unawaited(confirmFeedback(state));
    messenger.hideCurrentSnackBar();
    final bankBalance = message.balanceAfter;
    // Offer to match the balance the bank reports, but only if this alert is
    // the newest thing in the account (an older alert's balance is stale).
    if (added &&
        bankBalance != null &&
        state.isLatestFor(accountId, message.receivedAt) &&
        state.balanceFor(accountId) != bankBalance) {
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(tf(lang, 'smsBalanceDiffers', {
          'balance': formatEtb(bankBalance, hidden: state.hideBalances),
        })),
        action: SnackBarAction(
          label: t(lang, 'matchBalance'),
          onPressed: () => state.reconcileAccount(accountId, bankBalance),
        ),
      ));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(t(lang, added ? 'transactionConfirmed' : 'alreadyRecorded')),
    ));
  }

  String _receivedTime(DateTime time) {
    final now = DateTime.now();
    final clock =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return '${t(widget.state.language, 'today')} · $clock';
    }
    final date = widget.state.useEthiopianCalendar
        ? dateLabel(time, ethiopian: true, language: widget.state.language)
        : '${time.day}/${time.month}';
    return '$date · $clock';
  }
}

class _OlderAlertNote extends StatelessWidget {
  const _OlderAlertNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BirrColors.goldSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                size: 20, color: BirrColors.onGoldSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: BirrColors.onGoldSoft),
              ),
            ),
          ],
        ),
      );
}
