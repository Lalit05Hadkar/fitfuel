import 'dart:math';

import '../models.dart';

/// Daily calorie and macro targets using the Mifflin-St Jeor equation.
Targets calcTargets(Profile p) {
  final bmr = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age + (p.sex == Sex.male ? 5 : -161);
  final tdee = bmr * p.activity.factor;
  var kcal = tdee;
  if (p.goal == Goal.lose) kcal = max(tdee - 500, p.sex == Sex.male ? 1500 : 1200);
  if (p.goal == Goal.gain) kcal = tdee + 300;
  final k = (kcal / 10).round() * 10;
  final perKg = p.goal == Goal.gain ? 2.0 : (p.goal == Goal.lose ? 1.8 : 1.6);
  final protein = (p.weightKg * perKg).round();
  final fat = (k * 0.25 / 9).round();
  final carbs = max(0, ((k - protein * 4 - fat * 9) / 4).round());
  return Targets(
    kcal: k,
    protein: protein,
    carbs: carbs,
    fat: fat,
    waterMl: ((p.weightKg * 35) / 250).round() * 250,
    steps: 8000,
    bmr: bmr.round(),
    tdee: tdee.round(),
  );
}

/// Calories burned = MET × body weight (kg) × hours.
double burnedKcal(double met, double weightKg, int minutes) => met * weightKg * minutes / 60;

class ExerciseType {
  final String name;
  final double met;
  const ExerciseType(this.name, this.met);
}

const activities = <ExerciseType>[
  ExerciseType('Weight training', 5.0),
  ExerciseType('Running (8 km/h)', 8.3),
  ExerciseType('Brisk walking', 4.3),
  ExerciseType('Cycling', 7.5),
  ExerciseType('HIIT', 8.0),
  ExerciseType('Skipping rope', 11.0),
  ExerciseType('Swimming', 6.0),
  ExerciseType('Yoga', 2.5),
  ExerciseType('Badminton', 5.5),
  ExerciseType('Cricket', 4.8),
  ExerciseType('Football', 7.0),
  ExerciseType('Dance', 5.0),
];

class WorkoutPlan {
  final String name;
  final int minutes;
  final double met;
  final List<(String, String)> exercises;
  const WorkoutPlan(this.name, this.minutes, this.met, this.exercises);
}

const plans = <WorkoutPlan>[
  WorkoutPlan('Push day', 45, 5.0, [
    ('Bench press', '4 × 8'),
    ('Overhead press', '3 × 10'),
    ('Incline dumbbell press', '3 × 10'),
    ('Lateral raises', '3 × 15'),
    ('Tricep pushdowns', '3 × 12'),
  ]),
  WorkoutPlan('Pull day', 45, 5.0, [
    ('Lat pulldown', '4 × 10'),
    ('Barbell row', '4 × 8'),
    ('Seated cable row', '3 × 12'),
    ('Face pulls', '3 × 15'),
    ('Bicep curls', '3 × 12'),
  ]),
  WorkoutPlan('Leg day', 50, 5.0, [
    ('Squats', '4 × 8'),
    ('Romanian deadlift', '3 × 10'),
    ('Leg press', '3 × 12'),
    ('Walking lunges', '3 × 12 each'),
    ('Calf raises', '4 × 15'),
  ]),
  WorkoutPlan('Home, no equipment', 30, 8.0, [
    ('Push-ups', '4 × max'),
    ('Bodyweight squats', '4 × 20'),
    ('Plank', '3 × 45 s'),
    ('Burpees', '3 × 10'),
    ('Glute bridges', '3 × 15'),
  ]),
];
