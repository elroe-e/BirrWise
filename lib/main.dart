import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'device.dart';
import 'dialogs.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'lock_screen.dart';
import 'other_screens.dart';
import 'plan_screen.dart';
import 'sms_automation.dart';
import 'sms_inbox_screen.dart';
import 'strings.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const BirrWiseApp());
}

class BirrWiseApp extends StatefulWidget {
  const BirrWiseApp({super.key});

  @override
  State<BirrWiseApp> createState() => _BirrWiseAppState();
}

class _BirrWiseAppState extends State<BirrWiseApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final AppState state = AppState();
  final SmsAutomationService smsAutomation = SmsAutomationService();
  late Future<void> loading;
  bool locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loading = _load();
  }

  Future<void> _load() async {
    await state.load();
    locked = state.hasPin;
    final firstRun = !state.smsAutomationPrompted;
    if (firstRun) await state.markSmsAutomationPrompted();
    // Existing installs are asked about their banks once too.
    if (firstRun || !state.banksChosen) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final context = navigatorKey.currentContext;
        if (context == null) return;
        if (firstRun) await showWelcome(context, state);
        if (!state.banksChosen && context.mounted) {
          await showBankPicker(context, state);
        }
        if (firstRun &&
            Platform.isAndroid &&
            !state.bankSmsAutomationEnabled &&
            context.mounted) {
          unawaited(smsAutomation.requestEnable(context, state));
        }
      });
    }
    if (state.bankSmsAutomationEnabled) {
      await smsAutomation.synchronize(state);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused &&
        state.hasPin &&
        !filePickerOpen) {
      setState(() => locked = true);
    }
    if (lifecycleState == AppLifecycleState.resumed &&
        state.ready &&
        state.bankSmsAutomationEnabled) {
      unawaited(smsAutomation.synchronize(state));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          navigatorKey: navigatorKey,
          title: 'BirrWise',
          debugShowCheckedModeBanner: false,
          theme: birrTheme(dark: false, amharic: state.language == 'am'),
          darkTheme: birrTheme(dark: true, amharic: state.language == 'am'),
          themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(state.language),
          supportedLocales: const [Locale('en'), Locale('am')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Over every route, so a pushed screen cannot be seen while locked.
          builder: (context, child) => Stack(
            children: [
              child!,
              if (locked && state.ready && state.hasPin)
                // Screen readers must not read the ledger behind the lock.
                BlockSemantics(
                  child: PinLockScreen(
                    state: state,
                    onUnlock: () => setState(() => locked = false),
                  ),
                ),
            ],
          ),
          home: state.ready
              ? BirrWiseShell(state: state)
              : _LoadingScreen(
                  loading: loading,
                  onRetry: () => setState(() => loading = state.load()),
                ),
        ),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.loading, required this.onRetry});

  final Future<void> loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FutureBuilder<void>(
            future: loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 38),
                      const SizedBox(height: 12),
                      const Text('BirrWise could not open its local data.'),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                          onPressed: onRetry, child: const Text('Retry')),
                    ],
                  ),
                );
              }
              return const CircularProgressIndicator();
            },
          ),
        ),
      );
}

class BirrWiseShell extends StatefulWidget {
  const BirrWiseShell({required this.state, super.key});

  final AppState state;

  @override
  State<BirrWiseShell> createState() => _BirrWiseShellState();
}

class _BirrWiseShellState extends State<BirrWiseShell> {
  int selectedTab = 0;
  int planRouteKey = 0;
  final tabs = const [
    _TabInfo(Icons.home_outlined, Icons.home_rounded, 'home'),
    _TabInfo(Icons.event_note_outlined, Icons.event_note_rounded, 'plan'),
    _TabInfo(Icons.insights_outlined, Icons.insights_rounded, 'insights'),
    _TabInfo(Icons.grid_view_outlined, Icons.grid_view_rounded, 'hub'),
    _TabInfo(Icons.settings_outlined, Icons.settings_rounded, 'settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final lang = state.language;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: selectedTab == 0
            ? Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.spa_outlined,
                        size: 21, color: BirrColors.heroText),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'BirrWise',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 21,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              )
            : Text(
                t(lang, tabs[selectedTab].label),
                style: Theme.of(context).textTheme.titleLarge,
              ),
        actions: [
          IconButton(
            tooltip: t(lang, 'inbox'),
            onPressed: _openInbox,
            icon: Badge(
              isLabelVisible: state.pendingCount > 0,
              label: Text('${state.pendingCount}'),
              child: const Icon(Icons.mark_email_unread_outlined),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: IndexedStack(
              index: selectedTab,
              children: [
                HomeScreen(
                  state: state,
                  onInbox: _openInbox,
                  onPlan: _openBills,
                ),
                PlanScreen(
                  key: ValueKey(planRouteKey),
                  state: state,
                  initialSegment: planRouteKey == 0 ? 0 : 1,
                ),
                InsightsScreen(
                  state: state,
                  onInbox: _openInbox,
                  onBills: _openBills,
                ),
                HubScreen(state: state, onInbox: _openInbox),
                SettingsScreen(state: state),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: selectedTab == 0 || selectedTab == 1
          ? FloatingActionButton.extended(
              onPressed: () => showAddEntrySheet(context, state),
              icon: const Icon(Icons.add),
              label: Text(t(lang, 'add')),
              elevation: 2,
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: t(lang, tab.label),
            ),
        ],
      ),
    );
  }

  void _openBills() => setState(() {
        selectedTab = 1;
        planRouteKey++;
      });

  void _openInbox() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SmsInboxScreen(state: widget.state),
      ),
    );
  }
}

class _TabInfo {
  const _TabInfo(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
