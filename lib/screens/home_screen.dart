import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../services/health_service.dart';
import '../services/api_service.dart';

const _kSyncTask    = 'sculinebot.daily_sync';
const _kDefaultHost = 'https://jerry-050105010501-sculinebot.hf.space';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _userIdCtrl = TextEditingController();
  final _hostCtrl   = TextEditingController(text: _kDefaultHost);
  String  _status        = '尚未同步';
  bool    _syncing       = false;
  bool    _autoEnabled   = false;
  Map<String, dynamic>? _lastDecision;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _userIdCtrl.text = p.getString('line_user_id') ?? '';
      _hostCtrl.text   = p.getString('backend_host') ?? _kDefaultHost;
      _autoEnabled     = p.getBool('auto_sync') ?? false;
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('line_user_id', _userIdCtrl.text.trim());
    await p.setString('backend_host',  _hostCtrl.text.trim());
    await p.setBool('auto_sync', _autoEnabled);
  }

  Future<void> _syncNow() async {
    final userId = _userIdCtrl.text.trim();
    final host   = _hostCtrl.text.trim();
    if (userId.isEmpty || host.isEmpty) {
      setState(() => _status = '❌ 請先填入 LINE User ID 和後端網址');
      return;
    }
    setState(() { _syncing = true; _status = '同步中...'; });
    try {
      final metrics = await HealthService.fetchYesterday();
      if (metrics.isEmpty) {
        setState(() => _status = '⚠️ 未取得任何健康數據（請確認 Health Connect 權限）');
        return;
      }
      final ok = await ApiService.postMetrics(host: host, userId: userId, metrics: metrics);
      final decision = await ApiService.fetchHealthDecision(host: host, userId: userId);
      setState(() {
        _status       = ok ? '✅ 同步成功！已上傳 ${metrics.length} 筆數據' : '❌ 上傳失敗，請檢查網路';
        _lastDecision = decision;
      });
      await _savePrefs();
    } catch (e) {
      setState(() => _status = '❌ 錯誤：$e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    setState(() => _autoEnabled = value);
    await _savePrefs();
    if (value) {
      await Workmanager().registerPeriodicTask(
        _kSyncTask, _kSyncTask,
        frequency: const Duration(hours: 24),
        initialDelay: const Duration(minutes: 1),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } else {
      await Workmanager().cancelByUniqueName(_kSyncTask);
    }
  }

  Widget _decisionCard() {
    if (_lastDecision == null) return const SizedBox.shrink();
    final tier   = _lastDecision!['tier']   ?? '-';
    final action = _lastDecision!['action'] ?? '-';
    final emoji  = {'rest': '🛌', 'light': '🚶', 'maintain': '💪', 'train': '🔥'}[tier] ?? '❓';
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🧠 教練 Z 建議', style: TextStyle(color: Colors.green[300], fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('訓練強度：$emoji $tier', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text(action, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('SCULINEBOT 健康同步', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 設定區 ──
            const Text('設定', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _userIdCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('LINE User ID（從 bot 取得）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hostCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('後端網址'),
            ),
            const SizedBox(height: 20),

            // ── 手動同步按鈕 ──
            ElevatedButton.icon(
              onPressed: _syncing ? null : _syncNow,
              icon: _syncing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync),
              label: Text(_syncing ? '同步中...' : '立即同步昨日數據'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // ── 狀態顯示 ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_status, style: const TextStyle(color: Colors.white70)),
            ),

            // ── AI 建議卡片 ──
            _decisionCard(),

            const SizedBox(height: 24),

            // ── 每日自動同步開關 ──
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SwitchListTile(
                title: const Text('每日自動同步', style: TextStyle(color: Colors.white)),
                subtitle: const Text('背景在凌晨執行，不需開啟 App',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                value: _autoEnabled,
                onChanged: _toggleAutoSync,
                activeColor: const Color(0xFF059669),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              '此 App 僅讀取 Health Connect 數據並傳送給您的 AI 教練 Z，\n不會分享給任何第三方。',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
      );
}
