import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/repository.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/share_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE');

  final appState = AppState(Repository());
  await appState.load();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const EssensplanApp(),
    ),
  );
}

class EssensplanApp extends StatelessWidget {
  const EssensplanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Essensplan',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => _PhoneFrame(child: child!),
      home: Consumer<AppState>(
        builder: (_, app, _) =>
            app.household.onboarded ? const HomeShell() : const OnboardingScreen(),
      ),
    );
  }
}

/// Keeps the app at a comfortable phone width and centers it on wide screens
/// (web / tablet / desktop), so the layout and proportions stay phone-like —
/// like the reference cooking apps — instead of stretching across the page.
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  static const double _maxWidth = 460;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= _maxWidth + 24) return child;
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: ClipRect(
          child: SizedBox(
            width: _maxWidth,
            height: mq.size.height,
            child: MediaQuery(
              data: mq.copyWith(size: Size(_maxWidth, mq.size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
