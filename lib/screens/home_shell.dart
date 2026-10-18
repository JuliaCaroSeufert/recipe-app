import 'package:flutter/material.dart';

import '../services/share_service.dart';
import 'home/today_screen.dart';
import 'recipes/instagram_import.dart';
import 'recipes/recipes_screen.dart';
import 'shopping/shopping_screen.dart';
import 'week/week_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _open(int i) => setState(() => _index = i);

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

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScreen(onOpenTab: _open),
      const WeekScreen(),
      const RecipesScreen(),
      const ShoppingScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _open,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Heute',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Woche',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'Rezepte',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            selectedIcon: Icon(Icons.shopping_basket_rounded),
            label: 'Einkauf',
          ),
        ],
      ),
    );
  }
}
