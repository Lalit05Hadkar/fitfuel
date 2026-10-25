import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/nutrition.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'diary_screen.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});
  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  ExerciseType activity = activities.first;
  final minutes = TextEditingController(text: '30');

  @override
  void initState() {
    super.initState();
    minutes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final kg = s.profile!.weightKg;
    final mins = int.tryParse(minutes.text.trim()) ?? 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Train', style: FF.display(26)),
        const SizedBox(height: 12),
        const DateNav(),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Logged · ${niceDate(s.date)}', style: FF.display(19)),
            if (s.day.workouts.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 8), child: Muted('No workouts logged for this day.')),
            for (final w in s.day.workouts)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: FF.line))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Muted('${w.minutes} min', size: 12),
                    ]),
                  ),
                  Text('+${fmt(w.kcal)}', style: const TextStyle(color: FF.burn, fontWeight: FontWeight.w600)),
                  IconButton(tooltip: 'Delete ${w.name}', onPressed: () => s.removeWorkout(w.id), icon: const Icon(Icons.delete_outline)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Log an activity', style: FF.display(19)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<ExerciseType>(
                  initialValue: activity,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Activity'),
                  dropdownColor: FF.surface2,
                  items: [for (final a in activities) DropdownMenuItem(value: a, child: Text(a.name))],
                  onChanged: (v) => setState(() => activity = v ?? activity),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Muted('≈ ${fmt(burnedKcal(activity.met, kg, mins))} kcal burned'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (mins <= 0) {
                  toast(context, 'Enter minutes.');
                  return;
                }
                s.addWorkout(activity.name, mins, activity.met);
                toast(context, 'Workout logged');
              },
              child: const Text('Log workout'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Workout plans', style: FF.display(19)),
        const SizedBox(height: 8),
        for (final p in plans) ...[
          Panel(
            color: FF.sunk,
            outlined: true,
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Muted('${p.minutes} min · ${p.exercises.length} exercises', size: 12),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final (name, sets) in p.exercises)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [Expanded(child: Text(name)), Muted(sets, size: 14)]),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      s.addWorkout(p.name, p.minutes, p.met);
                      toast(context, '${p.name} logged');
                    },
                    child: const Text('Log this session'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
