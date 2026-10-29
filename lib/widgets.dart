import 'package:flutter/material.dart';
import 'app_state.dart';
import 'domain.dart';
import 'ethiopian_date.dart';
import 'strings.dart';
import 'theme.dart';

class BirrCard extends StatelessWidget {
  const BirrCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
    return onTap == null
        ? card
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: card,
          );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(action!),
          ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.neutral});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      ChipTone.neutral => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
      ChipTone.success => (BirrColors.forestSoft, BirrColors.forest),
      ChipTone.warning => (BirrColors.goldSoft, BirrColors.onGoldSoft),
      ChipTone.danger => (BirrColors.dangerSoft, BirrColors.onDangerSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        label,
        style:
            Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

enum ChipTone { neutral, success, warning, danger }

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.savings_outlined,
                  size: 38, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class HeroBalanceCard extends StatelessWidget {
  const HeroBalanceCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final hidden = state.hideBalances;
    final month = monthLabel(
      DateTime.now(),
      ethiopian: state.useEthiopianCalendar,
      language: state.language,
    );
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BirrColors.forest, BirrColors.forestDark],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: BirrColors.heroText.withValues(alpha: .08)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(state.language, 'balance'),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: BirrColors.goldOnDark,
                                )),
                    Text('${t(state.language, 'thisMonth')} · $month',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: BirrColors.heroText.withValues(alpha: .72),
                            )),
                  ],
                ),
              ),
              IconButton(
                tooltip:
                    t(state.language, hidden ? 'showBalances' : 'hideBalances'),
                onPressed: () =>
                    state.setPreference('hide', !state.hideBalances),
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: BirrColors.heroText,
                ),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              formatEtb(state.totalBalance, hidden: hidden),
              key: ValueKey(hidden),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'serif',
                fontSize: 34,
                height: 1.3,
                fontWeight: FontWeight.bold,
                color: BirrColors.heroText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              semanticsLabel:
                  hidden ? t(state.language, 'balanceHiddenSpoken') : null,
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: BirrColors.heroText.withValues(alpha: .16), height: 1),
          const SizedBox(height: 15),
          Row(
            children: [
              _HeroStat(
                label: t(state.language, 'income'),
                value: state.monthIncome,
                hidden: hidden,
                color: BirrColors.incomeOnDark,
                icon: Icons.south_west_rounded,
              ),
              _HeroStat(
                label: t(state.language, 'expenses'),
                value: state.monthExpenses,
                hidden: hidden,
                color: BirrColors.expenseOnDark,
                icon: Icons.north_east_rounded,
              ),
              _HeroStat(
                label: t(state.language, 'net'),
                value: state.monthIncome - state.monthExpenses,
                hidden: hidden,
                color: BirrColors.goldOnDark,
                icon: Icons.savings_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.hidden,
    required this.color,
    required this.icon,
  });

  final String label;
  final int value;
  final bool hidden;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: BirrColors.heroText.withValues(alpha: .75),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatEtb(value, hidden: hidden, withCode: false),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class TransactionRow extends StatelessWidget {
  const TransactionRow({required this.entry, required this.state, super.key});

  final FinanceEntry entry;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == EntryType.income ||
        entry.type == EntryType.transferIn ||
        (entry.type == EntryType.adjustment && entry.amount >= 0);
    final color = isIncome ? BirrColors.income : BirrColors.expense;
    final title = entry.party.isNotEmpty
        ? entry.party
        : entry.type == EntryType.adjustment
            ? t(state.language, 'adjustment')
            : t(state.language, entry.category);
    // Adjustments carry a signed amount; the sign is shown separately.
    final amount = entry.amount.abs();
    final date = _relativeDate(
      entry.date,
      state.language,
      state.useEthiopianCalendar,
    );
    final account =
        state.accounts.where((a) => a.id == entry.accountId).firstOrNull;
    final shop = entry.business ? '${t(state.language, 'shopTag')} · ' : '';
    final subtitle = '$shop${t(state.language, entry.category)} · $date'
        '${account == null ? '' : ' · ${account.name}'}';
    final sign = isIncome ? '+' : '−';
    return Semantics(
      container: true,
      label:
          '$title, $shop${t(state.language, entry.category)}, $date, $sign${formatEtb(amount, hidden: state.hideBalances)}',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 70),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(categoryIcon(entry.category), color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                        if (entry.source == EntrySource.sms) ...[
                          const SizedBox(width: 6),
                          const StatusChip('SMS', tone: ChipTone.success),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$sign${formatEtb(amount, hidden: state.hideBalances, withCode: false)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'serif',
                      fontSize: 15,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeDate(
      DateTime date, String language, bool ethiopianCalendar) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return t(language, 'today');
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return t(language, 'yesterday');
    }
    return dateLabel(
      date,
      ethiopian: ethiopianCalendar,
      language: language,
    );
  }
}

IconData categoryIcon(String category) => switch (category) {
      'food_groceries' => Icons.shopping_basket_outlined,
      'transport' => Icons.directions_car_outlined,
      'utilities' => Icons.bolt_outlined,
      'rent' => Icons.home_outlined,
      'airtime_data' => Icons.phone_android_outlined,
      'health' => Icons.local_hospital_outlined,
      'education' => Icons.school_outlined,
      'family_support' => Icons.favorite_border,
      'equb_iddir' => Icons.groups_outlined,
      'shopping' => Icons.shopping_bag_outlined,
      'entertainment' => Icons.movie_outlined,
      'business' => Icons.work_outline,
      'salary' => Icons.payments_outlined,
      'gift' => Icons.card_giftcard,
      _ => Icons.more_horiz,
    };

/// Each bank and wallet gets its own colour, so they are told apart at a
/// glance. Monograms only: no bank logos.
Color institutionColor(String institution) => switch (institution) {
      'Telebirr' => const Color(0xFF006699),
      'CBE' => const Color(0xFF7A1C7D),
      'CBE Birr' => const Color(0xFF9333EA),
      'Awash' || 'Awash Birr' => const Color(0xFF0D9488),
      'BOA' => const Color(0xFFD97706),
      'Dashen' || 'Amole' => const Color(0xFF1E40AF),
      'M-PESA' => const Color(0xFF059669),
      'Coopay' || 'Coop Bank' => const Color(0xFFEA580C),
      'Berhan' => const Color(0xFFCA8A04),
      'Bunna' => const Color(0xFF78350F),
      'Hibret' => const Color(0xFF15803D),
      'Ahadu' => const Color(0xFF0284C7),
      _ => BirrColors.forest,
    };

/// A tinted circle with the institution's first letters.
class InstitutionBadge extends StatelessWidget {
  const InstitutionBadge(this.institution, {this.radius = 20, super.key});

  final String institution;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = institutionColor(institution);
    final letters = institution.replaceAll(RegExp('[^A-Za-z]'), '');
    final monogram = (letters.length <= 3 && letters == letters.toUpperCase()
            ? letters
            : institution.substring(0, 1))
        .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: .14),
      child: Text(
        monogram,
        style: TextStyle(
          // Darkened so the letters stay readable on the light tint.
          color: Color.lerp(color, Colors.black, .3),
          fontWeight: FontWeight.w700,
          fontSize:
              radius * switch (monogram.length) { 1 => .8, 2 => .62, _ => .5 },
        ),
      ),
    );
  }
}
