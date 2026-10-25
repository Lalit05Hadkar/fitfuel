# FitFuel – Flutter app

Calorie and fitness tracker with AI meal photo scanning, built for Indian food.

## What's inside

```
lib/
  main.dart                 App entry + bottom-tab shell
  theme.dart                Colours and fonts (dark, lime accent)
  models.dart               Profile, FoodItem, DayLog, Workout (JSON-serialisable)
  app_state.dart            ChangeNotifier holding today's log and profile
  services/
    nutrition.dart          Calorie/macro targets (Mifflin-St Jeor), MET burn, workout plans
    storage_service.dart    Saves everything on the phone (shared_preferences)
    ai_service.dart         Calls the backend for photo scan, text logging, coach
  screens/
    onboarding_screen.dart  First-run setup and Edit profile
    home_screen.dart        Calorie ring, macros, water, steps, meals
    scan_screen.dart        Camera/gallery photo or text → AI → editable items → diary
    diary_screen.dart       Day-by-day meals, add by hand, swipe to delete
    train_screen.dart       Log activities, ready workout plans
    progress_screen.dart    Weight trend, 7-day calories, streaks, AI coach
  widgets/common.dart       Panel, CalorieRing, MacroCard, helpers
backend/
  main.py                   FastAPI server that talks to the AI (keeps the key off the phone)
test/widget_test.dart       Unit tests for targets, scaling, JSON
```

## 1. Run the backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
export GEMINI_API_KEY=your-key                      # Windows: set GEMINI_API_KEY=your-key
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Open http://localhost:8000/docs to try the endpoints in the browser.

## 2. Create the platform folders

This zip contains only the Dart code. Generate the Android/iOS folders once (existing files are kept):

```bash
cd fitfuel_app
flutter create . --org com.fitfuel --project-name fitfuel --platforms android,ios
flutter pub get
```

### Android: allow plain HTTP to your dev server
In `android/app/src/main/AndroidManifest.xml`, add to the `<application ...>` tag:

```xml
android:usesCleartextTraffic="true"
```

Remove it once the backend is on HTTPS.

### iOS: camera and photo permissions
In `ios/Runner/Info.plist`, inside `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Take photos of your meals to count calories.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pick meal photos to count calories.</string>
```

## 3. Run the app

```bash
# Android emulator (10.0.2.2 = your computer)
flutter run

# Real phone on the same Wi-Fi: use your computer's IP address
flutter run --dart-define=API_URL=http://192.168.1.20:8000

flutter test   # runs the unit tests
```

## Next steps
- Sync: replace `StorageService` with Firebase/Supabase so data survives reinstalls and works across devices.
- Food database: add IFCT / Open Food Facts lookups and barcode scanning (`mobile_scanner`).
- Health sync: `health` package for Google Fit / Apple Health steps.
- Notifications: water and meal reminders with `flutter_local_notifications`.
- Deploy the backend (Railway, Render, a small VPS) behind HTTPS and add user auth before launch.
