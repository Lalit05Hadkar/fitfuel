import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models.dart';

/// Talks to the FitFuel FastAPI backend (see /backend). The backend holds the
/// AI API key, so the key never ships inside the app.
///
/// Set the address when you run the app:
///   flutter run --dart-define=API_URL=http://192.168.1.20:8000
/// The default 10.0.2.2 is how the Android emulator reaches your computer.
class AiService {
  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8000');

  Future<ScanResult> analysePhoto(File photo, {required Meal meal, required Diet diet}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze/photo'))
      ..fields['meal'] = meal.name
      ..fields['diet'] = diet.label
      ..files.add(await http.MultipartFile.fromPath('photo', photo.path));
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 90)));
    return _parse(res);
  }

  Future<ScanResult> analyseText(String description, {required Meal meal, required Diet diet}) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/analyze/text'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': description, 'meal': meal.name, 'diet': diet.label}),
        )
        .timeout(const Duration(seconds: 90));
    return _parse(res);
  }

  Future<String> coach(Map<String, dynamic> summary) async {
    final res = await http
        .post(Uri.parse('$baseUrl/coach'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(summary))
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) throw AiException(_errorText(res));
    return (jsonDecode(res.body) as Map<String, dynamic>)['text'] as String? ?? '';
  }

  ScanResult _parse(http.Response res) {
    if (res.statusCode != 200) throw AiException(_errorText(res));
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final items = ((j['items'] as List?) ?? []).asMap().entries.map((e) {
      final m = Map<String, dynamic>.from(e.value as Map);
      m['id'] = '${DateTime.now().microsecondsSinceEpoch}-${e.key}';
      m['src'] = 'ai';
      return FoodItem.fromJson(m);
    }).toList();
    return ScanResult(name: (j['meal_name'] ?? '') as String, notes: (j['notes'] ?? '') as String, items: items);
  }

  String _errorText(http.Response res) {
    try {
      return (jsonDecode(res.body) as Map<String, dynamic>)['detail'].toString();
    } catch (_) {
      return 'Server error ${res.statusCode}';
    }
  }
}

class ScanResult {
  final String name;
  final String notes;
  final List<FoodItem> items;
  ScanResult({required this.name, required this.notes, required this.items});
}

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}
