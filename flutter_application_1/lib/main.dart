import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const defaultApiUrl = String.fromEnvironment('KHAYA_API_URL', defaultValue: '');
const pollInterval = Duration(seconds: 3);
const green = Color(0xFF00F08A);
const bg = Color(0xFF050A0B);
const card = Color(0xFF0A1516);
const muted = Color(0xFF81928F);

void main() => runApp(const KhayaApp());

class KhayaApp extends StatelessWidget {
  const KhayaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'KHAYA Mobile',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark),
      useMaterial3: true,
    ),
    home: const KhayaHome(),
  );
}

class KhayaHome extends StatefulWidget {
  const KhayaHome({super.key});
  @override State<KhayaHome> createState() => _KhayaHomeState();
}

class _KhayaHomeState extends State<KhayaHome> {
  late final TextEditingController api;
  Timer? timer;
  Map<String, dynamic>? payload;
  String? error;
  DateTime? lastFetch;
  int tab = 0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    api = TextEditingController(text: defaultApiUrl);
    _refresh();
    timer = Timer.periodic(pollInterval, (_) => _refresh());
  }

  @override
  void dispose() { timer?.cancel(); api.dispose(); super.dispose(); }

  String get baseUrl {
    var v = api.text.trim();
    while (v.endsWith('/')) v = v.substring(0, v.length - 1);
    return v;
  }

  Map<String, dynamic>? get ea {
    final v = payload?['ea'];
    return v is Map<String, dynamic> ? v : null;
  }

  bool get connected => payload != null && error == null;

  Future<void> _refresh() async {
    if (baseUrl.isEmpty || loading) return;
    loading = true;
    try {
      final r = await http.get(Uri.parse('$baseUrl/api/ea/status')).timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final decoded = jsonDecode(r.body);
      if (decoded is! Map<String, dynamic>) throw Exception('Invalid API response');
      if (!mounted) return;
      setState(() { payload = decoded; error = null; lastFetch = DateTime.now(); });
    } catch (_) {
      if (!mounted) return;
      setState(() { error = 'Backend unreachable'; });
    } finally { loading = false; }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_dashboard(), _markets(), _trades(), _risk(), _settings()];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF071011),
        indicatorColor: green.withValues(alpha: .12),
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: green), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart, color: green), label: 'Markets'),
          NavigationDestination(icon: Icon(Icons.swap_vert_outlined), selectedIcon: Icon(Icons.swap_vert, color: green), label: 'Trades'),
          NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield, color: green), label: 'Risk'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings, color: green), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _dashboard() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), physics: const AlwaysScrollableScrollPhysics(), children: [
      _header(), const SizedBox(height: 22), _label('KHAYA CONTROL CENTER'), const SizedBox(height: 10),
      _connection(), const SizedBox(height: 12), _eaCard(), const SizedBox(height: 12), _marketCard(),
      const SizedBox(height: 12), _accountCard(), const SizedBox(height: 12), _infrastructure(),
      if (ea == null) ...[const SizedBox(height: 16), _waiting()],
    ]),
  );

  Widget _header() => Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(border: Border.all(color: green, width: 1.5), borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('K1', style: TextStyle(color: green, fontWeight: FontWeight.w900, fontSize: 18)))),
    const SizedBox(width: 12),
    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('KHAYA', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 2)), Text('MOBILE', style: TextStyle(color: green, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 3))])),
    _pill(connected ? 'CONNECTED' : 'OFFLINE', connected),
  ]);

  Widget _connection() => _card(Icons.cloud_outlined, connected ? green : Colors.redAccent, 'BACKEND CONNECTION', connected ? 'CONNECTED' : 'UNREACHABLE', baseUrl);

  Widget _eaCard() {
    final v = ea;
    if (v == null) return _card(Icons.smart_toy_outlined, Colors.amber, 'EXPERT ADVISOR', 'WAITING FOR EA', 'No live EA heartbeat is available.');
    final running = v['ea_running'] == true;
    final auto = v['auto_trading'] == true;
    final session = v['session_open'] == true;
    final market = v['market_connected'] == true;
    final trading = v['trading_allowed'] == true;
    return _card(Icons.smart_toy_outlined, running ? green : Colors.redAccent, 'EXPERT ADVISOR', running ? 'RUNNING' : 'NOT RUNNING', null, [
      _line('EA Running', _yes(running), running), _line('Auto Trading', _yes(auto), auto), _line('Session', session ? 'OPEN' : 'CLOSED', session), _line('Market', market ? 'CONNECTED' : 'DISCONNECTED', market), _line('Trading', trading ? 'READY' : 'WAITING', trading),
    ]);
  }

  Widget _marketCard() {
    final v = ea;
    if (v == null) return _card(Icons.candlestick_chart_outlined, Colors.amber, 'MARKET CONNECTION', 'WAITING FOR EA', '');
    final market = v['market_connected'] == true;
    return _card(Icons.candlestick_chart_outlined, market ? green : Colors.redAccent, 'MARKET CONNECTION', null, null, [
      _line('Market', market ? 'CONNECTED' : 'DISCONNECTED', market), _line('Symbols Monitored', _d(v['symbols_monitored'])), _line('Symbols Ready', _d(v['symbols_ready'])), _line('Bullish', _d(v['bullish_symbols'])), _line('Bearish', _d(v['bearish_symbols'])),
    ]);
  }

  Widget _accountCard() {
    final v = ea;
    final has = v != null && (v.containsKey('account_balance') || v.containsKey('account_equity') || v.containsKey('open_positions'));
    return _card(Icons.account_balance_wallet_outlined, has ? green : muted, 'ACCOUNT DATA', has ? null : 'NOT PUBLISHED BY EA', null, [
      _line('Balance', _num(v?['account_balance'])), _line('Equity', _num(v?['account_equity'])), _line('Currency', _d(v?['account_currency'])), _line('Open Positions', _d(v?['open_positions'])),
    ]);
  }

  Widget _infrastructure() => _card(Icons.dns_outlined, green, 'INFRASTRUCTURE', null, null, [
    _line('Terminal', _d(ea?['terminal_name'])), _line('Broker', _d(ea?['broker_server'])), _line('VPS', _d(ea?['terminal_vps'])), _line('Terminal Build', _d(ea?['terminal_build'])), _line('Last Update', _d(payload?['last_update'])),
  ]);

  Widget _waiting() => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF171309), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF8A6A10))), child: const Row(children: [Icon(Icons.hourglass_empty, color: Colors.amber), SizedBox(width: 12), Expanded(child: Text('WAITING FOR EA\nLive values will appear when the real KHAYA EA publishes its heartbeat.', style: TextStyle(color: Colors.white70, fontSize: 12)))]));

  Widget _markets() => ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [_title('Markets', Icons.show_chart), const SizedBox(height: 18), _marketCard(), const SizedBox(height: 12), _card(Icons.radar_outlined, green, 'EA TELEMETRY', ea == null ? 'WAITING FOR EA' : 'LIVE', 'Values are read from the KHAYA status endpoint.')]);

  Widget _trades() {
    final v = ea;
    final count = v?['open_positions'];
    return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [_title('Live Trades', Icons.swap_vert), const SizedBox(height: 18), _card(Icons.receipt_long_outlined, count != null ? green : muted, 'LIVE POSITIONS', count == null ? 'NO POSITION FEED' : _d(count), count == null ? 'The current EA status contract does not publish position details.' : 'Open-position count supplied by the EA.')]);
  }

  Widget _risk() {
    final allowed = ea?['trading_allowed'] == true;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [_title('Risk Controls', Icons.shield), const SizedBox(height: 18), _card(Icons.security_outlined, ea == null ? Colors.amber : (allowed ? green : Colors.amber), 'TRADING PERMISSION', ea == null ? 'WAITING FOR EA' : (allowed ? 'READY' : 'WAITING'), 'This screen reflects the real EA permission state. It does not create or alter risk settings.')]);
  }

  Widget _settings() => ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 28), children: [
    _title('Settings', Icons.settings), const SizedBox(height: 18),
    _card(Icons.link_outlined, green, 'KHAYA API', null, null, [
      TextField(controller: api, keyboardType: TextInputType.url, onSubmitted: (_) => _refresh(), decoration: InputDecoration(labelText: 'Backend URL', hintText: 'https://your-khaya-api.example', filled: true, fillColor: const Color(0xFF0B1718), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
      const SizedBox(height: 10), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.sync), label: const Text('CONNECT / REFRESH'))),
      const SizedBox(height: 12), _line('Polling', 'Every 3 seconds'), _line('Last successful fetch', lastFetch?.toLocal().toString() ?? '—'), _line('API status', connected ? 'CONNECTED' : 'OFFLINE', connected), if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
    ]),
    const SizedBox(height: 12), _card(Icons.info_outline, muted, 'REAL DATA POLICY', 'NO FAKE VALUES', 'The app only displays fields supplied by the live KHAYA API. Missing fields are shown as unavailable.'),
  ]);

  Widget _title(String s, IconData i) => Row(children: [Icon(i, color: green, size: 30), const SizedBox(width: 12), Text(s, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))]);
  Widget _label(String s) => Text(s, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5));
  Widget _pill(String s, bool good) { final c = good ? green : Colors.redAccent; return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: .45))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 8, color: c), const SizedBox(width: 6), Text(s, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold))])); }
  Widget _card(IconData icon, Color iconColor, String title, String? value, String? subtitle, [List<Widget> children = const []]) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF163A3A))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: iconColor, size: 28), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)))]), if (value != null) ...[const SizedBox(height: 8), Text(value, style: TextStyle(color: iconColor == muted ? Colors.white70 : iconColor, fontSize: 22, fontWeight: FontWeight.w900))], if (subtitle != null && subtitle.isNotEmpty) ...[const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10))], if (children.isNotEmpty) ...[const SizedBox(height: 8), ...children]]));
  Widget _line(String a, String b, [bool? good]) { final c = good == null ? Colors.white : (good ? green : Colors.redAccent); return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(a, style: const TextStyle(color: muted, fontSize: 11))), Flexible(child: Text(b, textAlign: TextAlign.right, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)))])); }
  String _d(dynamic v) => v == null ? '—' : v is bool ? (v ? 'YES' : 'NO') : v.toString();
  String _num(dynamic v) => v == null ? '—' : v is num ? v.toStringAsFixed(2) : v.toString();
  String _yes(bool v) => v ? 'YES' : 'NO';
}
