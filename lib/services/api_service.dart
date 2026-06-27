import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  /// POST health metrics to /api/ingest/apple_health/<userId>
  /// (Backend endpoint accepts both Apple Health and Android Health Connect)
  static Future<bool> postMetrics({
    required String host,
    required String userId,
    required List<Map<String, dynamic>> metrics,
  }) async {
    if (metrics.isEmpty) return true;
    final uri = Uri.parse('$host/api/ingest/android_health_connect/$userId');
    final body = jsonEncode({'data': metrics});
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 30));
    return response.statusCode == 200;
  }

  /// Fetch current sync status and latest health decision from backend.
  static Future<Map<String, dynamic>?> fetchHealthDecision({
    required String host,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse('$host/api/health/decision/$userId');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
