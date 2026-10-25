import 'package:fitfuel/models.dart';
import 'package:fitfuel/services/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mifflin-St Jeor targets for a 22 y, 175 cm, 75 kg man losing fat', () {
    final p = Profile(
      name: 'Test',
      sex: Sex.male,
      age: 22,
      heightCm: 175,
      weightKg: 75,
      activity: Activity.light,
      goal: Goal.lose,
      diet: Diet.veg,
    );
    final t = calcTargets(p);
    expect(t.bmr, 1739); // 750 + 1093.75 - 110 + 5
    expect(t.tdee, 2391); // × 1.375
    expect(t.kcal, 1890); // − 500, rounded to 10
    expect(t.protein, 135); // 1.8 g/kg
  });

  test('Food items scale with grams', () {
    final f = FoodItem(id: '1', name: 'Dal', grams: 150, kcal: 120, protein: 6);
    final g = f.scaledTo(300);
    expect(g.kcal, 240);
    expect(g.protein, 12);
  });

  test('Day log survives a JSON round trip', () {
    final d = DayLog()..waterMl = 1500;
    d.meals[Meal.lunch]!.add(FoodItem(id: 'a', name: 'Roti', kcal: 112));
    final back = DayLog.fromJson(d.toJson());
    expect(back.waterMl, 1500);
    expect(back.kcal, 112);
  });
}
