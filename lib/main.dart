import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'services/health_service.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';

const _kSyncTask = 'sculinebot.daily_sync';

/// WorkManager background callback (top-level, not a class method)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _kSyncTask) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('line_user_id') ?? '';
      final host   = prefs.getString('backend_host') ?? '';
      if (userId.isEmpty || host.isEmpty) return true;
      try {
        final metrics = await HealthService.fetchYesterday();
        await ApiService.postMetrics(host: host, userId: userId, metrics: metrics);
      } catch (_) {}
    }
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(const SculinebotSyncApp());
}

class SculinebotSyncApp extends StatelessWidget {
  const SculinebotSyncApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SCULINEBOT 健康同步',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF059669),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      );
}
