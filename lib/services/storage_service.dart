import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Local storage on the phone. Swap this class for a Firebase/Supabase or
/// FastAPI-backed implementation later without touching the screens.
class StorageService {
  late SharedPreferences _prefs;

  Future<void> init() async => _prefs = await SharedPreferences.getInstance();

  Profile? loadProfile() {
    final raw = _prefs.getString('profile');
    if (raw == null) return null;
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(Profile p) => _prefs.setString('profile', jsonEncode(p.toJson()));

  DayLog loadDay(String key) {
    final raw = _prefs.getString('day:$key');
    if (raw == null) return DayLog();
    try {
      return DayLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return DayLog();
    }
  }

  Future<void> saveDay(String key, DayLog d) => _prefs.setString('day:$key', jsonEncode(d.toJson()));

  Future<void> clearAll() => _prefs.clear();
}
