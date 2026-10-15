import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/week_plan.dart';
import '../../state/app_state.dart';
import '../../utils/dates.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final plans = app.plans;
    final currentId = app.currentPlan?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Wochen-Archiv')),
      body: plans.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Hier sammeln sich deine geplanten Wochen. Du kannst eine '
                  'alte Woche jederzeit erneut einplanen ("recyceln").',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
              children: [
                for (final plan in plans)
                  _PlanCard(
                    plan: plan,
                    isCurrent: plan.id == currentId,
                  ),
              ],
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final WeekPlan plan;
  final bool isCurrent;

  const _PlanCard({required this.plan, required this.isCurrent});

  int get _mealCount =>
      plan.allSlots.where((s) => s.hasRecipe).length;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(isCurrent ? '★' : '📅'),
        ),
        title: Text(weekRangeLabel(plan.startDate, plan.days.length)),
        subtitle: Text(isCurrent
            ? 'Aktive Woche · $_mealCount Gerichte'
            : '$_mealCount Gerichte'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _onAction(context, app, value),
          itemBuilder: (_) => [
            if (!isCurrent)
              const PopupMenuItem(
                value: 'activate',
                child: ListTile(
                  leading: Icon(Icons.play_arrow),
                  title: Text('Als aktive Woche setzen'),
                ),
              ),
            const PopupMenuItem(
              value: 'recycle',
              child: ListTile(
                leading: Icon(Icons.autorenew),
                title: Text('Erneut einplanen'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Löschen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(
      BuildContext context, AppState app, String value) async {
    switch (value) {
      case 'activate':
        await app.setCurrentPlan(plan.id);
        if (context.mounted) Navigator.pop(context);
      case 'recycle':
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 90)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 730)),
          helpText: 'Neues Startdatum (z. B. in 3 Monaten)',
        );
        if (picked == null || !context.mounted) return;
        await app.recyclePlan(plan, mondayOf(picked));
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Woche neu eingeplant.')),
          );
        }
      case 'delete':
        await app.deletePlan(plan.id);
    }
  }
}
