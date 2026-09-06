import 'package:flutter/material.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import 'package:flutter/services.dart';

class RelationshipWebScreen extends StatefulWidget {
  final GameEngine engine;
  RelationshipWebScreen({super.key, required this.engine});
  @override State<RelationshipWebScreen> createState() => _RelationshipWebScreenState();
}

class _RelationshipWebScreenState extends State<RelationshipWebScreen> with SingleTickerProviderStateMixin {
  GameEngine get engine => widget.engine;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  dynamic get player {
    final career = engine.careerPlayer;
    if (career == null) return null;
    return engine.players.where((p) => p.id == career.id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p == null) return Scaffold(body: Center(child: Text('Brak aktywnej kariery.')));
    final web = engine.worldEngine.relationshipWebEngine;
    final r = web.forPlayer(p);

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(title: Text('RELACJE'), backgroundColor: FPGTheme.bg, actions: [
        IconButton(
          tooltip: 'Odśwież',
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {});
          },
          icon: Icon(Icons.tune_rounded),
        ),
      ]),
      body: FadeTransition(
        opacity: _entrance,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 28),
          children: [
          _hero(p, r),
          SizedBox(height: 16),
          Text('TWOJA SIEĆ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: FPGTheme.muted)),
          SizedBox(height: 10),
          _relationCard('TRENER', Icons.sports_soccer, r.coach, 'Zaufanie, rola i decyzje szkoleniowca.'),
          _relationCard('KLUB', Icons.stadium_outlined, r.club, 'Zarząd, kontrakt i Twoja pozycja w klubie.'),
          _relationCard('AGENT', Icons.business_center_outlined, r.agent, 'Negocjacje, rynek i plan kariery.'),
          _relationCard('KIBICE', Icons.groups_outlined, r.fans, 'Wsparcie trybun i reputacja wśród fanów.'),
          _relationCard('MEDIA', Icons.newspaper_outlined, r.media, 'Narracja medialna i presja wokół zawodnika.'),
          SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('OSTATNIE ZMIANY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: FPGTheme.muted))),
            Text('${r.history.length} zapisów', style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w800)),
          ]),
          SizedBox(height: 10),
          if (r.history.isEmpty)
            _emptyHistory()
          else
            ...r.history.reversed.take(10).map(_historyTile),
          ],
        ),
      ),
    );
  }

  Widget _hero(dynamic p, dynamic r) => Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: FPGTheme.heroGradient),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: FPGTheme.cardBorder),
      boxShadow: [BoxShadow(color: Color(0x331B9CFF), blurRadius: 26, offset: Offset(0, 8))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('RELATIONSHIP WEB', style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      SizedBox(height: 7),
      Text(p.name, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
      SizedBox(height: 4),
      Text('Każda decyzja zostawia ślad w świecie.', style: TextStyle(color: FPGTheme.muted)),
      SizedBox(height: 16),
      Row(children: [
        _mini('TRENER', r.coach), _mini('KLUB', r.club), _mini('AGENT', r.agent),
      ]),
    ]),
  );

  Widget _mini(String label, int value) => Expanded(child: Container(
    margin: EdgeInsets.only(right: 8),
    padding: EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: FPGTheme.surface2, borderRadius: BorderRadius.circular(13)),
    child: Column(children: [Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 8, color: FPGTheme.muted, fontWeight: FontWeight.w800))]),
  ));

  Widget _relationCard(String title, IconData icon, int value, String description) => Container(
    margin: EdgeInsets.only(bottom: 10),
    padding: EdgeInsets.all(15),
    decoration: FPGDecor.glowCard(),
    child: Column(children: [
      Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: Color(0x221B9CFF), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: Colors.lightBlueAccent)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          SizedBox(height: 3),
          Text(description, style: TextStyle(color: FPGTheme.muted, fontSize: 11)),
        ])),
        Text('$value', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      ]),
      SizedBox(height: 11),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: value / 100, minHeight: 7, backgroundColor: FPGTheme.surface2, color: FPGTheme.accent)),
    ]),
  );

  Widget _historyTile(dynamic h) => Container(
    margin: EdgeInsets.only(bottom: 8),
    decoration: FPGDecor.glowCard(),
    child: ListTile(
      leading: Icon(h.delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: h.delta >= 0 ? Colors.lightBlueAccent : Colors.redAccent),
      title: Text('${h.target.toUpperCase()}  ${h.delta > 0 ? '+' : ''}${h.delta}', style: TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(h.reason, style: TextStyle(color: FPGTheme.muted)),
    ),
  );

  Widget _emptyHistory() => Container(
    padding: EdgeInsets.all(24),
    decoration: FPGDecor.glowCard(),
    child: Column(children: [Icon(Icons.hub_outlined, size: 38, color: FPGTheme.muted), SizedBox(height: 10), Text('BRAK ZMIAN'), SizedBox(height: 5), Text('Podejmuj decyzje i obserwuj, jak świat reaguje.', textAlign: TextAlign.center, style: TextStyle(color: FPGTheme.muted))]),
  );
}

extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
