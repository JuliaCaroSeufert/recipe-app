import 'package:flutter/material.dart';

import '../services/share_service.dart';
import 'recipes/instagram_import.dart';
import 'recipes/recipes_screen.dart';
import 'settings/settings_screen.dart';
import 'shopping/shopping_screen.dart';
import 'week/week_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Open the import screen whenever a caption/link is shared into the app.
    ShareService.instance.onText = (text) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.push(MaterialPageRoute(
        builder: (_) => InstagramImportScreen(sharedText: text),
      ));
    };
    ShareService.instance.start();
  }

  static const _screens = [
    WeekScreen(),
    RecipesScreen(),
    ShoppingScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Woche',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Rezepte',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Einkauf',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}
