// Data models for FitFuel. Everything serialises to plain JSON so it can be
// stored locally now and synced to a backend later.

enum Sex { male, female }

enum Goal { lose, maintain, gain }

enum Activity { sedentary, light, moderate, very }

enum Diet { veg, egg, nonveg, vegan, jain }

enum Meal { breakfast, lunch, snacks, dinner }

extension GoalLabel on Goal {
  String get label => const {Goal.lose: 'Lose fat', Goal.maintain: 'Maintain', Goal.gain: 'Build muscle'}[this]!;
}

extension ActivityLabel on Activity {
  String get label => const {
        Activity.sedentary: 'Desk job, little exercise',
        Activity.light: 'Light: 1–3 workouts a week',
        Activity.moderate: 'Moderate: 3–5 workouts a week',
        Activity.very: 'Very active: 6–7 hard sessions',
      }[this]!;
  double get factor => const {
        Activity.sedentary: 1.2,
        Activity.light: 1.375,
        Activity.moderate: 1.55,
        Activity.very: 1.725,
      }[this]!;
}

extension DietLabel on Diet {
  String get label => const {
        Diet.veg: 'Vegetarian',
        Diet.egg: 'Eggetarian',
        Diet.nonveg: 'Non-veg',
        Diet.vegan: 'Vegan',
        Diet.jain: 'Jain',
      }[this]!;
}

extension MealLabel on Meal {
  String get label => const {
        Meal.breakfast: 'Breakfast',
        Meal.lunch: 'Lunch',
        Meal.snacks: 'Snacks',
        Meal.dinner: 'Dinner',
      }[this]!;
  static Meal forHour(int h) => h < 11
      ? Meal.breakfast
      : h < 16
          ? Meal.lunch
          : h < 19
              ? Meal.snacks
              : Meal.dinner;
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

double _d(Object? v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

class WeightEntry {
  final String date; // yyyy-MM-dd
  final double kg;
  const WeightEntry(this.date, this.kg);
  Map<String, dynamic> toJson() => {'d': date, 'w': kg};
  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(j['d'] as String, _d(j['w']));
}

class Profile {
  String name;
  Sex sex;
  int age;
  double heightCm;
  double weightKg;
  double? targetWeightKg;
  Activity activity;
  Goal goal;
  Diet diet;
  List<WeightEntry> weights;

  Profile({
    required this.name,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.targetWeightKg,
    required this.activity,
    required this.goal,
    required this.diet,
    List<WeightEntry>? weights,
  }) : weights = weights ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'sex': sex.name,
        'age': age,
        'height': heightCm,
        'weight': weightKg,
        'targetWeight': targetWeightKg,
        'activity': activity.name,
        'goal': goal.name,
        'diet': diet.name,
        'weights': weights.map((w) => w.toJson()).toList(),
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] ?? '') as String,
        sex: _enum(Sex.values, j['sex'], Sex.male),
        age: _d(j['age']).round(),
        heightCm: _d(j['height']),
        weightKg: _d(j['weight']),
        targetWeightKg: j['targetWeight'] == null ? null : _d(j['targetWeight']),
        activity: _enum(Activity.values, j['activity'], Activity.light),
        goal: _enum(Goal.values, j['goal'], Goal.maintain),
        diet: _enum(Diet.values, j['diet'], Diet.veg),
        weights: ((j['weights'] as List?) ?? [])
            .map((e) => WeightEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class FoodItem {
  final String id;
  String name;
  String portion;
  double grams;
  double kcal;
  double protein;
  double carbs;
  double fat;
  double confidence; // 0–1, only for AI results
  String source; // ai | manual

  FoodItem({
    required this.id,
    required this.name,
    this.portion = '',
    this.grams = 100,
    required this.kcal,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.confidence = 0,
    this.source = 'manual',
  });

  /// Returns a copy scaled to a new gram weight (used when the user corrects a portion).
  FoodItem scaledTo(double newGrams) {
    final f = grams <= 0 ? 1.0 : newGrams / grams;
    return FoodItem(
      id: id,
      name: name,
      portion: portion,
      grams: newGrams,
      kcal: kcal * f,
      protein: protein * f,
      carbs: carbs * f,
      fat: fat * f,
      confidence: confidence,
      source: source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'portion': portion,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'confidence': confidence,
        'src': source,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: (j['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()) as String,
        name: (j['name'] ?? 'Food') as String,
        portion: (j['portion'] ?? '') as String,
        grams: _d(j['grams'] ?? 100),
        kcal: _d(j['kcal']),
        protein: _d(j['protein'] ?? j['protein_g']),
        carbs: _d(j['carbs'] ?? j['carbs_g']),
        fat: _d(j['fat'] ?? j['fat_g']),
        confidence: _d(j['confidence']),
        source: (j['src'] ?? 'manual') as String,
      );
}

class Workout {
  final String id;
  final String name;
  final int minutes;
  final double kcal;
  const Workout({required this.id, required this.name, required this.minutes, required this.kcal});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'minutes': minutes, 'kcal': kcal};
  factory Workout.fromJson(Map<String, dynamic> j) =>
      Workout(id: j['id'] as String, name: j['name'] as String, minutes: _d(j['minutes']).round(), kcal: _d(j['kcal']));
}

class DayLog {
  final Map<Meal, List<FoodItem>> meals;
  int waterMl;
  int steps;
  final List<Workout> workouts;

  DayLog({Map<Meal, List<FoodItem>>? meals, this.waterMl = 0, this.steps = 0, List<Workout>? workouts})
      : meals = meals ?? {for (final m in Meal.values) m: <FoodItem>[]},
        workouts = workouts ?? [];

  Iterable<FoodItem> get allFoods => meals.values.expand((e) => e);
  double get kcal => allFoods.fold(0, (s, f) => s + f.kcal);
  double get protein => allFoods.fold(0, (s, f) => s + f.protein);
  double get carbs => allFoods.fold(0, (s, f) => s + f.carbs);
  double get fat => allFoods.fold(0, (s, f) => s + f.fat);
  double get burned => workouts.fold(0, (s, w) => s + w.kcal);
  bool get hasFood => allFoods.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'meals': {for (final e in meals.entries) e.key.name: e.value.map((f) => f.toJson()).toList()},
        'water': waterMl,
        'steps': steps,
        'workouts': workouts.map((w) => w.toJson()).toList(),
      };

  factory DayLog.fromJson(Map<String, dynamic> j) {
    final m = Map<String, dynamic>.from((j['meals'] as Map?) ?? {});
    return DayLog(
      meals: {
        for (final meal in Meal.values)
          meal: ((m[meal.name] as List?) ?? [])
              .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
      },
      waterMl: _d(j['water']).round(),
      steps: _d(j['steps']).round(),
      workouts: ((j['workouts'] as List?) ?? [])
          .map((e) => Workout.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class Targets {
  final int kcal, protein, carbs, fat, waterMl, steps, bmr, tdee;
  const Targets({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.waterMl,
    required this.steps,
    required this.bmr,
    required this.tdee,
  });
}
