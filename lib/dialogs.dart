import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'domain.dart';
import 'ethiopian_date.dart';
import 'strings.dart';
import 'widgets.dart';

Future<bool> showAddAccountDialog(BuildContext context, AppState state) async {
  final name = TextEditingController();
  final number = TextEditingController();
  final opening = TextEditingController(text: '0');
  var institution = 'Cash';
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(state.language, 'addAccount'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setModalState(() {}),
                decoration: InputDecoration(
                  labelText: t(state.language, 'accountName'),
                  hintText: 'e.g. Everyday spending',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: institution,
                decoration: InputDecoration(
                    labelText: t(state.language, 'institution')),
                items: const [
                  'Cash',
                  'Telebirr',
                  'CBE',
                  'Awash',
                  'BOA',
                  'Dashen',
                ]
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) =>
                    setModalState(() => institution = value ?? 'Cash'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: opening,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration: InputDecoration(
                  labelText: t(state.language, 'openingBalance'),
                  prefixText: 'ETB  ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: number,
                decoration: InputDecoration(
                    labelText: t(state.language, 'maskedNumber')),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: name.text.trim().isEmpty
                      ? null
                      : () async {
                          final amount = parseEtbToSantim(opening.text);
                          if (amount == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(t(state.language,
                                    'invalidOpeningBalance')),
                              ),
                            );
                            return;
                          }
                          await state.addAccount(
                            name: name.text,
                            institution: institution,
                            openingBalance: amount,
                            maskedNumber: number.text,
                          );
                          if (context.mounted) Navigator.pop(context, true);
                        },
                  child: Text(t(state.language, 'create')),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
  number.dispose();
  opening.dispose();
  return result ?? false;
}

Future<void> showAddEntrySheet(
  BuildContext context,
  AppState state, {
  EntryType initialType = EntryType.expense,
}) async {
  if (state.accounts.where((a) => !a.archived).isEmpty) {
    await showAddAccountDialog(context, state);
    if (!context.mounted || state.accounts.every((a) => a.archived)) return;
  }
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        _AddEntrySheet(state: state, initialType: initialType),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t(state.language, 'saved'))),
    );
  }
}

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet({required this.state, required this.initialType});

  final AppState state;
  final EntryType initialType;

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  late EntryType type = widget.initialType;
  String category = 'food_groceries';
  DateTime date = DateTime.now();
  late String accountId;
  late String toAccountId;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final active = widget.state.accounts.where((a) => !a.archived).toList();
    accountId = active.first.id;
    toAccountId = active.length > 1 ? active[1].id : accountId;
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final lang = state.language;
    final theme = Theme.of(context);
    final amount = parseEtbToSantim(amountController.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(lang, 'add'), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 18),
            SegmentedButton<EntryType>(
              segments: [
                ButtonSegment(
                  value: EntryType.expense,
                  label: Text(t(lang, 'expense')),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: EntryType.income,
                  label: Text(t(lang, 'income')),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                ButtonSegment(
                  value: EntryType.transferOut,
                  label: Text(t(lang, 'transfer')),
                  icon: const Icon(Icons.swap_horiz_rounded),
                ),
              ],
              selected: {type},
              onSelectionChanged: (selection) =>
                  setState(() => type = selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 18),
            Center(
              child: TextField(
                controller: amountController,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'serif',
                  fontSize: 38,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  prefixText: 'ETB ',
                  hintText: '0.00',
                  border: InputBorder.none,
                  filled: false,
                  errorText: error,
                ),
                onChanged: (_) => setState(() => error = null),
              ),
            ),
            const SizedBox(height: 12),
            Text(t(lang, 'account'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _AccountPicker(
              state: state,
              selectedId: accountId,
              onSelected: (id) => setState(() => accountId = id),
            ),
            if (type == EntryType.transferOut) ...[
              const SizedBox(height: 14),
              Text(t(lang, 'toAccount'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _AccountPicker(
                state: state,
                selectedId: toAccountId,
                onSelected: (id) => setState(() => toAccountId = id),
              ),
            ],
            if (type != EntryType.transferOut) ...[
              const SizedBox(height: 14),
              Text(t(lang, 'category'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _CategoryPicker(
                language: lang,
                selected: category,
                onSelected: (value) => setState(() => category = value),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t(lang, 'description'),
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final chosen = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (chosen != null) setState(() => date = chosen);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day
                      ? t(lang, 'today')
                      : dateLabel(
                          date,
                          ethiopian: state.useEthiopianCalendar,
                          language: lang,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: amount == null || amount == 0 || saving
                    ? null
                    : () async {
                        if (type == EntryType.transferOut &&
                            accountId == toAccountId) {
                          setState(
                              () => error = t(lang, 'chooseTwoAccounts'));
                          return;
                        }
                        setState(() => saving = true);
                        try {
                          if (type == EntryType.transferOut) {
                            await state.addTransfer(
                              fromAccountId: accountId,
                              toAccountId: toAccountId,
                              amount: amount,
                              note: noteController.text,
                              date: date,
                            );
                          } else {
                            await state.addEntry(
                              accountId: accountId,
                              type: type,
                              amount: amount,
                              category: category,
                              party: noteController.text,
                              date: date,
                            );
                          }
                          await confirmFeedback(state);
                          if (context.mounted) Navigator.pop(context, true);
                        } on ArgumentError catch (e) {
                          setState(() {
                            error = e.message?.toString() ??
                                t(lang, 'invalidAmount');
                            saving = false;
                          });
                        } on StateError catch (e) {
                          setState(() {
                            error = e.message.toString();
                            saving = false;
                          });
                        }
                      },
                child: Text(t(lang, 'save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.state,
    required this.selectedId,
    required this.onSelected,
  });

  final AppState state;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: state.accounts
              .where((a) => !a.archived)
              .map(
                (account) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(account.name),
                    selected: account.id == selectedId,
                    onSelected: (_) => onSelected(account.id),
                  ),
                ),
              )
              .toList(),
        ),
      );
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.language,
    required this.selected,
    required this.onSelected,
  });

  final String language;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .92,
        children: financeCategories.keys.map((key) {
          final isSelected = selected == key;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(categoryIcon(key), size: 20),
                  const SizedBox(height: 4),
                  Text(
                    t(language, key),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
}

Future<void> showAddGoalDialog(BuildContext context, AppState state) async {
  final title = TextEditingController();
  final target = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(state.language, 'newGoal'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          TextField(
            controller: title,
            decoration:
                InputDecoration(labelText: t(state.language, 'goalName')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            decoration: InputDecoration(
              labelText: t(state.language, 'target'),
              prefixText: 'ETB  ',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () async {
                final value = parseEtbToSantim(target.text);
                if (title.text.trim().isEmpty || value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.language == 'am'
                          ? 'የግብ ስም እና ትክክለኛ መጠን ያስገቡ።'
                          : 'Enter a goal name and a valid target amount.'),
                    ),
                  );
                  return;
                }
                await state.createGoal(title.text, value);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(t(state.language, 'create')),
            ),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  target.dispose();
}

Future<void> showAddBillDialog(BuildContext context, AppState state) async {
  final title = TextEditingController();
  final amount = TextEditingController();
  final dueDay = TextEditingController(text: '1');
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t(state.language, 'newBill'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          TextField(
              controller: title,
              decoration:
                  InputDecoration(labelText: t(state.language, 'description'))),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            decoration: InputDecoration(
              labelText: t(state.language, 'amount'),
              prefixText: 'ETB  ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dueDay,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: state.language == 'am' ? 'የወሩ ቀን' : 'Day of month',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () async {
                final value = parseEtbToSantim(amount.text);
                if (title.text.trim().isEmpty || value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.language == 'am'
                          ? 'የክፍያ ስም እና ትክክለኛ መጠን ያስገቡ።'
                          : 'Enter a bill name and a valid amount.'),
                    ),
                  );
                  return;
                }
                await state.createBill(
                  title: title.text,
                  amount: value,
                  dueDay: int.tryParse(dueDay.text) ?? 1,
                  accountId:
                      state.accounts.where((a) => !a.archived).firstOrNull?.id,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(t(state.language, 'create')),
            ),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  amount.dispose();
  dueDay.dispose();
}

Future<void> confirmFeedback(AppState state) async {
  if (state.hapticsEnabled) await HapticFeedback.selectionClick();
  if (state.soundEnabled) await SystemSound.play(SystemSoundType.click);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
