import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'scan_screen.dart';

String niceDate(String key) {
  final t = todayKey();
  if (key == t) return 'Today';
  if (key == shiftKey(t, -1)) return 'Yesterday';
  return DateFormat('EEE, d MMM').format(fromKey(key));
}

class DateNav extends StatelessWidget {
  const DateNav({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final isToday = s.date == todayKey();
    return Panel(
      radius: 18,
      padding: const EdgeInsets.all(6),
      child: Row(children: [
        IconButton(tooltip: 'Previous day', onPressed: () => s.openDay(shiftKey(s.date, -1)), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text(niceDate(s.date), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        IconButton(
          tooltip: 'Next day',
          onPressed: isToday ? null : () => s.openDay(shiftKey(s.date, 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    );
  }
}

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.targets;
    final d = s.day;
    final left = t.kcal - d.kcal + d.burned;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Diary', style: FF.display(26)),
        const SizedBox(height: 12),
        const DateNav(),
        const SizedBox(height: 12),
        Panel(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _pair('Eaten', fmt(d.kcal), FF.fg),
            _pair('Burned', fmt(d.burned), FF.burn),
            _pair('Left', fmt(left), left < 0 ? FF.burn : FF.accent),
          ]),
        ),
        for (final m in Meal.values) ...[
          const SizedBox(height: 12),
          _MealCard(meal: m),
        ],
      ],
    );
  }

  Widget _pair(String k, String v, Color c) => Text.rich(TextSpan(children: [
        TextSpan(text: '$k ', style: const TextStyle(color: FF.muted)),
        TextSpan(text: v, style: TextStyle(fontWeight: FontWeight.w700, color: c)),
      ]));
}

class _MealCard extends StatelessWidget {
  final Meal meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.day.meals[meal]!;
    final kcal = items.fold<double>(0, (a, f) => a + f.kcal);
    return Panel(
      color: FF.sunk,
      outlined: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(meal.label, style: FF.display(16)),
              Muted('${fmt(kcal)} kcal'),
            ]),
          ),
          IconButton.filledTonal(
            tooltip: 'Scan food for ${meal.label}',
            icon: const Icon(Icons.photo_camera_outlined, color: FF.accent),
            onPressed: () {
              ScanScreen.preselect.value = meal;
              Shell.goTo(context, 2);
            },
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Add food by hand',
            icon: const Icon(Icons.add, color: FF.accent),
            onPressed: () => showManualFoodSheet(context, meal),
          ),
        ]),
        for (final f in items)
          Dismissible(
            key: ValueKey(f.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              color: const Color(0x33FF8A3D),
              child: const Icon(Icons.delete_outline, color: FF.burn),
            ),
            onDismissed: (_) {
              s.removeFood(meal, f.id);
              toast(context, 'Removed ${f.name}');
            },
            child: Container(
              padding: const EdgeInsets.only(top: 10),
              margin: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: FF.line))),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Muted('${f.portion.isEmpty ? '' : '${f.portion} · '}P ${one(f.protein)} · C ${one(f.carbs)} · F ${one(f.fat)}', size: 12),
                  ]),
                ),
                Text(fmt(f.kcal)),
              ]),
            ),
          ),
      ]),
    );
  }
}

Future<void> showManualFoodSheet(BuildContext context, Meal meal) {
  final name = TextEditingController();
  final portion = TextEditingController();
  final kcal = TextEditingController();
  final p = TextEditingController();
  final c = TextEditingController();
  final f = TextEditingController();
  double n(TextEditingController t) => double.tryParse(t.text.trim()) ?? 0;
  Widget field(TextEditingController t, String label, {bool number = true}) => TextField(
        controller: t,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      );

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: FF.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add to ${meal.label}', style: FF.display(20)),
        const SizedBox(height: 12),
        field(name, 'Food', number: false),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: field(portion, 'Portion (e.g. 1 katori)', number: false)),
          const SizedBox(width: 10),
          Expanded(child: field(kcal, 'Calories (kcal)')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: field(p, 'Protein g')),
          const SizedBox(width: 10),
          Expanded(child: field(c, 'Carbs g')),
          const SizedBox(width: 10),
          Expanded(child: field(f, 'Fat g')),
        ]),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty || kcal.text.trim().isEmpty) {
              toast(ctx, 'Add a name and calories.');
              return;
            }
            ctx.read<AppState>().addFoods(meal, [
              FoodItem(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name.text.trim(),
                portion: portion.text.trim(),
                kcal: n(kcal),
                protein: n(p),
                carbs: n(c),
                fat: n(f),
              )
            ]);
            Navigator.of(ctx).pop();
          },
          child: const Text('Add food'),
        ),
      ]),
    ),
  );
}
