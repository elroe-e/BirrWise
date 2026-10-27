import 'package:flutter/material.dart';

import 'app_state.dart';
import 'dialogs.dart';
import 'domain.dart';
import 'ethiopian_date.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.state,
    required this.onInbox,
    required this.onPlan,
    super.key,
  });

  final AppState state;
  final VoidCallback onInbox;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final lang = state.language;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? t(lang, 'goodMorning')
        : now.hour < 17
            ? t(lang, 'goodAfternoon')
            : t(lang, 'goodEvening');
    final hasData = state.accounts.isNotEmpty || state.entries.isNotEmpty;
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final upcoming = [
      ...state.bills.where((b) =>
          b.active &&
          b.lastPaidPeriod != period &&
          HomeScreen._dueIn(b.dueDay) <= 7)
    ]..sort((a, b) => _dueIn(a.dueDay).compareTo(_dueIn(b.dueDay)));
    final recent = state.recentEntries.take(10).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
      children: [
        Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          monthLabel(
            now,
            ethiopian: state.useEthiopianCalendar,
            language: lang,
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (state.pendingCount > 0) ...[
          const SizedBox(height: 18),
          _PendingBanner(
            count: state.pendingCount,
            language: lang,
            onTap: onInbox,
          ),
        ],
        const SizedBox(height: 22),
        HeroBalanceCard(state: state),
        if (!hasData) ...[
          const SizedBox(height: 26),
          EmptyState(
            title: t(lang, 'emptyHome'),
            message: t(lang, 'noAccounts'),
            action: t(lang, 'addFirst'),
            onAction: () => showAddEntrySheet(context, state),
          ),
        ] else ...[
          const SizedBox(height: 25),
          SectionHeading(
            t(lang, 'accounts'),
            action: t(lang, 'add'),
            onAction: () => showAddAccountDialog(context, state),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.accounts.where((a) => !a.archived).length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final activeAccounts =
                    state.accounts.where((a) => !a.archived).toList();
                if (index == activeAccounts.length) {
                  return _AddAccountCard(
                    label: t(lang, 'addAccount'),
                    onTap: () => showAddAccountDialog(context, state),
                  );
                }
                return _AccountCard(
                    account: activeAccounts[index], state: state);
              },
            ),
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 25),
            SectionHeading(
              t(lang, 'upcomingBills'),
              action: t(lang, 'seeAll'),
              onAction: onPlan,
            ),
            const SizedBox(height: 8),
            ...upcoming.take(3).map(
                  (bill) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _UpcomingBillTile(
                      bill: bill,
                      state: state,
                      onPaid: () async {
                        try {
                          await state.payBill(bill);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t(lang, 'paid')),
                                action: SnackBarAction(
                                  label: t(lang, 'undo'),
                                  onPressed: () => state.undoBillPayment(bill),
                                ),
                              ),
                            );
                          }
                        } on StateError {
                          if (context.mounted) {
                            showAddAccountDialog(context, state);
                          }
                        }
                      },
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 25),
          SectionHeading(
            t(lang, 'recent'),
            action: t(lang, 'seeAll'),
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TransactionsScreen(state: state),
              ),
            ),
          ),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(t(lang, 'noDataHint'),
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...recent
                .map((entry) => TransactionRow(entry: entry, state: state)),
        ],
      ],
    );
  }

  static int _dueIn(int day) {
    final now = DateTime.now();
    final monthLength = DateTime(now.year, now.month + 1, 0).day;
    final due =
        DateTime(now.year, now.month, day.clamp(1, monthLength).toInt());
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({
    required this.count,
    required this.language,
    required this.onTap,
  });

  final int count;
  final String language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: BirrColors.goldSoft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    color: BirrColors.onGoldSoft),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    language == 'am'
                        ? '$count አዲስ የባንክ መልዕክት'
                        : '$count bank message${count == 1 ? '' : 's'} to review',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BirrColors.onGoldSoft,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(t(language, 'review'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: BirrColors.onGoldSoft,
                        )),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: BirrColors.onGoldSoft),
              ],
            ),
          ),
        ),
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.state});

  final Account account;
  final AppState state;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 174,
        child: BirrCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      account.institution.substring(0, 1).toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Text(account.institution,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                ],
              ),
              const Spacer(),
              Text(account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                formatEtb(state.balanceFor(account.id),
                    hidden: state.hideBalances, withCode: false),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontFamily: 'serif',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (account.maskedNumber.isNotEmpty)
                Text('•• ${account.maskedNumber}',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

class _AddAccountCard extends StatelessWidget {
  const _AddAccountCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 144,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline, size: 28),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _UpcomingBillTile extends StatelessWidget {
  const _UpcomingBillTile({
    required this.bill,
    required this.state,
    required this.onPaid,
  });

  final Bill bill;
  final AppState state;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    final period =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final paid = bill.lastPaidPeriod == period;
    final due = HomeScreen._dueIn(bill.dueDay);
    final label = paid
        ? t(state.language, 'paid')
        : due < 0
            ? (state.language == 'am' ? 'ያለፈ' : 'Overdue')
            : due == 0
                ? (state.language == 'am' ? 'ዛሬ' : 'Due today')
                : '${t(state.language, 'due')} $due ${state.language == 'am' ? 'ቀን' : 'days'}';
    return BirrCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${formatEtb(bill.amount, hidden: state.hideBalances)} · $label',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: due < 0 && !paid
                            ? BirrColors.onDangerSoft
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!paid)
            FilledButton.tonal(
              onPressed: onPaid,
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(t(state.language, 'markPaid')),
            )
          else
            const StatusChip('✓', tone: ChipTone.success),
        ],
      ),
    );
  }
}

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({required this.state, super.key});

  final AppState state;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final search = TextEditingController();
  String filter = 'all';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  // A pushed route: listen so deletes and undo show up immediately.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => _buildList(context),
      );

  Widget _buildList(BuildContext context) {
    final state = widget.state;
    final results = state.recentEntries.where((entry) {
      final q = search.text.toLowerCase();
      final matchesText = entry.party.toLowerCase().contains(q) ||
          entry.note.toLowerCase().contains(q);
      final matchesType = filter == 'all' ||
          (filter == 'income' && entry.type == EntryType.income) ||
          (filter == 'expense' && entry.type == EntryType.expense);
      return matchesText && matchesType;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(t(state.language, 'transactions'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t(state.language, 'search'),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              scrollDirection: Axis.horizontal,
              children: [
                for (final value in ['all', 'income', 'expense'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t(state.language, value)),
                      selected: filter == value,
                      onSelected: (_) => setState(() => filter = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(t(state.language, 'noDataHint'),
                        textAlign: TextAlign.center),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      for (var i = 0; i < results.length; i++) ...[
                        if (i == 0 ||
                            !_sameDay(results[i - 1].date, results[i].date))
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Text(
                              _dayLabel(
                                results[i].date,
                                state.language,
                                state.useEthiopianCalendar,
                              ),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        Dismissible(
                          key: ValueKey(results[i].id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: BirrColors.dangerSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: BirrColors.onDangerSoft),
                          ),
                          onDismissed: (_) async {
                            final removedEntries =
                                await state.removeEntry(results[i].id);
                            if (removedEntries == null || !context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t(state.language,
                                    'transactionRemoved')),
                                action: SnackBarAction(
                                  label: t(state.language, 'undo'),
                                  onPressed: () =>
                                      state.restoreEntries(removedEntries),
                                ),
                              ),
                            );
                          },
                          child:
                              TransactionRow(entry: results[i], state: state),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date, String language, bool useEthiopianCalendar) {
    final now = DateTime.now();
    if (_sameDay(date, now)) return t(language, 'today');
    final yesterday = now.subtract(const Duration(days: 1));
    if (_sameDay(date, yesterday)) {
      return t(language, 'yesterday');
    }
    return dateLabel(
      date,
      ethiopian: useEthiopianCalendar,
      language: language,
    );
  }
}
