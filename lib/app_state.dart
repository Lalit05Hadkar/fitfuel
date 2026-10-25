import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'services/nutrition.dart';
import 'services/storage_service.dart';

String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime fromKey(String k) => DateFormat('yyyy-MM-dd').parse(k);
String todayKey() => dayKey(DateTime.now());
String shiftKey(String k, int days) => dayKey(fromKey(k).add(Duration(days: days)));

class AppState extends ChangeNotifier {
  final StorageService storage;
  AppState(this.storage);

  Profile? profile;
  String date = todayKey();
  DayLog day = DayLog();

  Targets get targets => calcTargets(profile!);

  void load() {
    profile = storage.loadProfile();
    day = storage.loadDay(date);
  }

  // ---------- profile ----------
  Future<void> saveProfile(Profile p) async {
    final today = todayKey();
    if (p.weights.isEmpty || profile?.weightKg != p.weightKg) {
      p.weights = [...p.weights.where((w) => w.date != today), WeightEntry(today, p.weightKg)];
    }
    profile = p;
    await storage.saveProfile(p);
    notifyListeners();
  }

  Future<void> logWeight(double kg) async {
    final p = profile!;
    final today = todayKey();
    p.weights = [...p.weights.where((w) => w.date != today), WeightEntry(today, kg)]
      ..sort((a, b) => a.date.compareTo(b.date));
    p.weightKg = kg;
    await storage.saveProfile(p);
    notifyListeners();
  }

  // ---------- days ----------
  void openDay(String key) {
    if (key.compareTo(todayKey()) > 0) return;
    date = key;
    day = storage.loadDay(key);
    notifyListeners();
  }

  DayLog dayFor(String key) => key == date ? day : storage.loadDay(key);

  Future<void> _save() async {
    await storage.saveDay(date, day);
    notifyListeners();
  }

  Future<void> addFoods(Meal meal, List<FoodItem> foods) {
    day.meals[meal]!.addAll(foods);
    return _save();
  }

  Future<void> removeFood(Meal meal, String id) {
    day.meals[meal]!.removeWhere((f) => f.id == id);
    return _save();
  }

  Future<void> changeWater(int deltaMl) {
    day.waterMl = (day.waterMl + deltaMl).clamp(0, 10000).toInt();
    return _save();
  }

  Future<void> setSteps(int steps) {
    day.steps = steps.clamp(0, 200000).toInt();
    return _save();
  }

  Future<void> addWorkout(String name, int minutes, double met) {
    day.workouts.add(Workout(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      minutes: minutes,
      kcal: burnedKcal(met, profile!.weightKg, minutes),
    ));
    return _save();
  }

  Future<void> removeWorkout(String id) {
    day.workouts.removeWhere((w) => w.id == id);
    return _save();
  }

  // ---------- stats ----------
  /// Days in a row with food logged, counting back from today (or yesterday if today is empty).
  int get streak {
    var k = todayKey();
    if (!dayFor(k).hasFood) k = shiftKey(k, -1);
    var n = 0;
    while (n < 365 && dayFor(k).hasFood) {
      n++;
      k = shiftKey(k, -1);
    }
    return n;
  }

  /// Last 7 days, oldest first.
  List<(String, DayLog)> get lastWeek {
    final t = todayKey();
    return [for (var i = 6; i >= 0; i--) (shiftKey(t, -i), dayFor(shiftKey(t, -i)))];
  }

  Map<String, dynamic> coachSummary() {
    final p = profile!;
    final t = targets;
    return {
      'profile': {
        'sex': p.sex.name,
        'age': p.age,
        'height_cm': p.heightCm,
        'weight_kg': p.weightKg,
        'goal': p.goal.name,
        'diet': p.diet.label,
      },
      'targets': {'kcal': t.kcal, 'protein_g': t.protein, 'carbs_g': t.carbs, 'fat_g': t.fat, 'water_ml': t.waterMl, 'steps': t.steps},
      'last_7_days': [
        for (final (k, d) in lastWeek)
          {
            'date': k,
            'kcal': d.kcal.round(),
            'protein_g': d.protein.round(),
            'carbs_g': d.carbs.round(),
            'fat_g': d.fat.round(),
            'burned': d.burned.round(),
            'steps': d.steps,
            'water_ml': d.waterMl,
            'logged': d.hasFood,
          }
      ],
      'today_foods': [for (final e in day.meals.entries) for (final f in e.value) '${e.key.label}: ${f.name}'],
      'weights': [for (final w in p.weights.reversed.take(6).toList().reversed) '${w.date}: ${w.kg} kg'],
    };
  }
}
