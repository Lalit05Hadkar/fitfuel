import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/nutrition.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// First-run setup, also reused as "Edit profile".
class OnboardingScreen extends StatefulWidget {
  final Profile? existing;
  const OnboardingScreen({super.key, this.existing});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController name, age, height, weight, target;
  late Sex sex;
  late Goal goal;
  late Activity activity;
  late Diet diet;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    name = TextEditingController(text: p?.name ?? '');
    age = TextEditingController(text: p == null ? '' : '${p.age}');
    height = TextEditingController(text: p == null ? '' : one(p.heightCm));
    weight = TextEditingController(text: p == null ? '' : one(p.weightKg));
    target = TextEditingController(text: p?.targetWeightKg == null ? '' : one(p!.targetWeightKg!));
    sex = p?.sex ?? Sex.male;
    goal = p?.goal ?? Goal.lose;
    activity = p?.activity ?? Activity.light;
    diet = p?.diet ?? Diet.veg;
    for (final c in [age, height, weight]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [name, age, height, weight, target]) {
      c.dispose();
    }
    super.dispose();
  }

  Profile? _read() {
    final a = int.tryParse(age.text.trim());
    final h = double.tryParse(height.text.trim());
    final w = double.tryParse(weight.text.trim());
    if (a == null || h == null || w == null) return null;
    if (a < 13 || a > 90 || h < 120 || h > 230 || w < 30 || w > 250) return null;
    return Profile(
      name: name.text.trim(),
      sex: sex,
      age: a,
      heightCm: h,
      weightKg: w,
      targetWeightKg: double.tryParse(target.text.trim()),
      activity: activity,
      goal: goal,
      diet: diet,
      weights: widget.existing?.weights ?? [],
    );
  }

  Future<void> _save() async {
    final p = _read();
    if (p == null) {
      toast(context, 'Check age, height and weight.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await context.read<AppState>().saveProfile(p);
    if (widget.existing != null) {
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
    }
  }

  Widget _chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) onPick) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(label(v)),
              selected: v == selected,
              onSelected: (_) => setState(() => onPick(v)),
            )
        ],
      );

  Widget _field(TextEditingController c, String label, {bool number = true}) => TextField(
        controller: c,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.name,
        decoration: InputDecoration(labelText: label),
      );

  Widget _section(String title, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Muted(title), const SizedBox(height: 8), child],
      );

  @override
  Widget build(BuildContext context) {
    final p = _read();
    final t = p == null ? null : calcTargets(p);
    final editing = widget.existing != null;
    return Scaffold(
      appBar: editing ? AppBar(title: const Text('Edit profile')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (!editing) ...[
              Text('Welcome to FitFuel', style: FF.display(28)),
              const SizedBox(height: 6),
              const Muted("We'll work out your calorie and protein targets. You can change them any time.", size: 15),
              const SizedBox(height: 20),
            ],
            _field(name, 'Your name', number: false),
            const SizedBox(height: 16),
            _section('Sex (for the calorie formula)',
                _chips(Sex.values, sex, (s) => s == Sex.male ? 'Male' : 'Female', (v) => sex = v)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _field(age, 'Age')),
              const SizedBox(width: 10),
              Expanded(child: _field(height, 'Height (cm)')),
              const SizedBox(width: 10),
              Expanded(child: _field(weight, 'Weight (kg)')),
            ]),
            const SizedBox(height: 16),
            _section('Goal', _chips(Goal.values, goal, (g) => g.label, (v) => goal = v)),
            const SizedBox(height: 16),
            _field(target, 'Target weight (kg, optional)'),
            const SizedBox(height: 16),
            _section('Activity level', _chips(Activity.values, activity, (a) => a.label, (v) => activity = v)),
            const SizedBox(height: 16),
            _section('Diet', _chips(Diet.values, diet, (d) => d.label, (v) => diet = v)),
            const SizedBox(height: 20),
            Panel(
              color: FF.sunk,
              outlined: true,
              child: t == null
                  ? const Muted('Fill in age, height and weight to see your daily target.')
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Muted('YOUR DAILY TARGET', size: 12),
                      const SizedBox(height: 4),
                      Text('${fmt(t.kcal)} kcal', style: FF.display(32)),
                      const SizedBox(height: 4),
                      Muted('Protein ${t.protein} g · Carbs ${t.carbs} g · Fat ${t.fat} g · Water ${t.waterMl / 1000} L'),
                      const SizedBox(height: 4),
                      Muted('BMR ${fmt(t.bmr)} kcal, maintenance ${fmt(t.tdee)} kcal (Mifflin-St Jeor)', size: 12),
                    ]),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(editing ? 'Save changes' : 'Start tracking')),
          ],
        ),
      ),
    );
  }
}
