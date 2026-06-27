import 'package:health/health.dart';

/// Reads yesterday's health data from Android Health Connect.
/// Returns a list of metric maps ready to POST to the backend.
class HealthService {
  static final _health = Health();

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WEIGHT,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  ];

  static const _typeToKey = {
    HealthDataType.STEPS:                        'steps',
    HealthDataType.HEART_RATE:                   'heart_rate',
    HealthDataType.ACTIVE_ENERGY_BURNED:         'active_calories',
    HealthDataType.SLEEP_ASLEEP:                 'sleep',
    HealthDataType.WEIGHT:                       'weight',
    HealthDataType.HEART_RATE_VARIABILITY_SDNN:  'hrv',
  };

  /// Request Health Connect permissions. Returns true if granted.
  static Future<bool> requestPermissions() async {
    final perms = _types.map((_) => HealthDataAccess.READ).toList();
    return _health.requestAuthorization(_types, permissions: perms);
  }

  /// Fetch all relevant metrics for yesterday.
  static Future<List<Map<String, dynamic>>> fetchYesterday() async {
    final now       = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final today     = DateTime(now.year, now.month, now.day);
    final dateStr   = yesterday.toIso8601String();

    final granted = await requestPermissions();
    if (!granted) return [];

    final points = await _health.getHealthDataFromTypes(
      startTime: yesterday,
      endTime:   today,
      types:     _types,
    );

    // Aggregate: sum steps/calories/sleep; average heart_rate/hrv; last weight
    final Map<String, List<double>> buckets = {};
    for (final p in points) {
      final key = _typeToKey[p.type];
      if (key == null) continue;
      final val = (p.value as NumericHealthValue).numericValue.toDouble();
      buckets.putIfAbsent(key, () => []).add(val);
    }

    final List<Map<String, dynamic>> metrics = [];
    buckets.forEach((type, vals) {
      double value;
      if (type == 'steps' || type == 'active_calories') {
        value = vals.reduce((a, b) => a + b);          // sum
      } else if (type == 'sleep') {
        value = vals.reduce((a, b) => a + b) / 60.0;  // minutes → hours
      } else if (type == 'weight') {
        value = vals.last;                              // most recent
      } else {
        value = vals.reduce((a, b) => a + b) / vals.length; // average
      }
      metrics.add({'type': type, 'value': value, 'date': dateStr});
    });

    return metrics;
  }
}
