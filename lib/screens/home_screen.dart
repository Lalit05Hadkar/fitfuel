import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile!;
    final t = s.targets;
    final d = s.day;
    final hour = DateTime.now().hour;
    final hello = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Muted(DateFormat('EEEE, d MMM').format(DateTime.now())),
              Text(p.name.isEmpty ? hello : '$hello, ${p.name}', style: FF.display(24)),
            ]),
          ),
          Tooltip(
            message: 'Days in a row with food logged',
            child: Panel(
              radius: 999,
              color: FF.surface2,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                const Icon(Icons.local_fire_department, size: 16, color: FF.burn),
                const SizedBox(width: 4),
                Text('${s.streak}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnboardingScreen(existing: p))),
          ),
        ]),
        if (s.date != todayKey()) ...[
          const SizedBox(height: 8),
          Panel(
            color: FF.sunk,
            outlined: true,
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(child: Muted('Showing ${DateFormat('d MMM').format(fromKey(s.date))}')),
              TextButton(onPressed: () => s.openDay(todayKey()), child: const Text('Back to today')),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Panel(
          radius: 28,
          child: Row(children: [
            CalorieRing(eaten: d.kcal, burned: d.burned, goal: t.kcal),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _stat('Goal', fmt(t.kcal)),
                const SizedBox(height: 10),
                _stat('Eaten', fmt(d.kcal)),
                const SizedBox(height: 10),
                _stat('Burned', '+${fmt(d.burned)}', FF.burn),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: MacroCard(label: 'Protein', value: d.protein, goal: t.protein, color: FF.accent)),
          const SizedBox(width: 10),
          Expanded(child: MacroCard(label: 'Carbs', value: d.carbs, goal: t.carbs, color: FF.water)),
          const SizedBox(width: 10),
          Expanded(child: MacroCard(label: 'Fat', value: d.fat, goal: t.fat, color: FF.burn)),
        ]),
        const SizedBox(height: 12),
        Material(
          color: FF.accent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Shell.goTo(context, 2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: FF.accentInk, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.center_focus_strong, color: FF.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Snap your meal', style: FF.display(17, color: FF.accentInk)),
                    const Text('Photo or a quick description, AI does the counting',
                        style: TextStyle(color: FF.accentInk, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: FF.accentInk),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _WaterCard(goalMl: t.waterMl)),
          const SizedBox(width: 10),
          Expanded(child: _StepsCard(goal: t.steps)),
        ]),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Meals', style: FF.display(19))),
              OutlinedButton(onPressed: () => Shell.goTo(context, 1), child: const Text('Open diary')),
            ]),
            if (!d.hasFood)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Muted('Nothing logged yet. Snap your first meal or add it from the diary.'),
              ),
            for (final m in Meal.values)
              if (d.meals[m]!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Muted(d.meals[m]!.map((f) => f.name).join(', ')),
                      ]),
                    ),
                    Muted('${fmt(d.meals[m]!.fold<double>(0, (a, f) => a + f.kcal))} kcal'),
                  ]),
                ),
          ]),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, [Color color = FF.fg]) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Muted(label, size: 12),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: color)),
        ],
      );
}

class _WaterCard extends StatelessWidget {
  final int goalMl;
  const _WaterCard({required this.goalMl});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final ml = s.day.waterMl;
    return Panel(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('Water', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Icon(Icons.water_drop_outlined, size: 18, color: FF.water),
        ]),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(text: one(ml / 1000), style: FF.display(22)),
          TextSpan(text: ' / ${goalMl / 1000} L', style: const TextStyle(color: FF.muted, fontSize: 13)),
        ])),
        const SizedBox(height: 8),
        ProgressBar(value: goalMl == 0 ? 0 : ml / goalMl, color: FF.water),
        const SizedBox(height: 8),
        Row(children: [
          IconButton.filledTonal(
            tooltip: 'Remove a glass',
            onPressed: () => s.changeWater(-250),
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => s.changeWater(250),
              child: const Text('+250 ml'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StepsCard extends StatefulWidget {
  final int goal;
  const _StepsCard({required this.goal});
  @override
  State<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<_StepsCard> {
  final ctl = TextEditingController();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Panel(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Expanded(child: Text('Steps', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Icon(Icons.directions_walk, size: 18, color: FF.accent),
        ]),
        const SizedBox(height: 6),
        Text(fmt(s.day.steps), style: FF.display(22)),
        const SizedBox(height: 8),
        ProgressBar(value: s.day.steps / widget.goal, color: FF.accent),
        const SizedBox(height: 8),
        TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter steps', isDense: true),
          onSubmitted: (v) {
            final n = int.tryParse(v.trim());
            if (n != null) s.setSteps(n);
            ctl.clear();
          },
        ),
      ]),
    );
  }
}
