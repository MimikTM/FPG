import 'package:flutter/material.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../models/relationship_event.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../core/audio_service.dart';

class RelationshipEventsScreen extends StatefulWidget {
  final GameEngine engine;
  RelationshipEventsScreen({super.key, required this.engine});
  @override
  State<RelationshipEventsScreen> createState() => _RelationshipEventsScreenState();
}

class _RelationshipEventsScreenState extends State<RelationshipEventsScreen> with SingleTickerProviderStateMixin {
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

  int get day => DateTime(engine.state.year, engine.state.month, engine.state.day)
      .difference(DateTime(2026, 1, 1))
      .inDays;

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p == null) {
      return Scaffold(
        body: Center(child: Text('Brak aktywnej kariery.')),
      );
    }

    final all = engine.worldEngine.relationshipEventsEngine.pending
        .where((e) => e.playerId == p.id)
        .toList();
    final pending = all.where((e) => !e.resolved).toList();
    final resolved = all.where((e) => e.resolved).toList().reversed.toList();

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(title: Text('Relacje • Wydarzenia'), backgroundColor: FPGTheme.bg),
      body: FadeTransition(
        opacity: _entrance,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: FPGDecor.heroCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RELATIONSHIP EVENTS', style: TextStyle(color: FPGTheme.muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                SizedBox(height: 7),
                Text('Sytuacje, na które musisz odpowiedzieć.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Decyzje wpływają na relacje, reputację i dalszy przebieg kariery.', style: TextStyle(color: FPGTheme.muted)),
              ],
            ),
          ),
          SizedBox(height: 18),
          if (pending.isEmpty)
            Container(
              decoration: FPGDecor.glowCard(),
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Column(
                  children: [
                    Icon(Icons.forum_outlined, size: 40, color: FPGTheme.muted),
                    SizedBox(height: 10),
                    Text('Brak aktywnych scen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(height: 5),
                    Text('Nowe sytuacje pojawią się, gdy świat kariery stworzy odpowiedni kontekst.', textAlign: TextAlign.center, style: TextStyle(color: FPGTheme.muted)),
                  ],
                ),
              ),
            ),
          ...pending.map((e) => _scene(e, p)),
          if (resolved.isNotEmpty) ...[
            SizedBox(height: 16),
            Text('OSTATNIE DECYZJE', style: TextStyle(color: FPGTheme.muted, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
            SizedBox(height: 8),
            ...resolved.take(5).map(_resolved),
          ],
          ],
        ),
      ),
    );
  }

  Widget _scene(RelationshipEvent e, dynamic p) {
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: FPGDecor.glowCard(),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: FPGTheme.accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(e.target.toUpperCase(), style: TextStyle(color: FPGTheme.accent, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
                Spacer(),
                Text('ETAP ${e.stage} • DZIEŃ ${e.createdAbsoluteDay}', style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w800)),
              ],
            ),
            SizedBox(height: 12),
            Text(e.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            SizedBox(height: 7),
            Text(e.description, style: TextStyle(color: FPGTheme.muted, height: 1.35)),
            SizedBox(height: 15),
            ...e.choices.map(
              (c) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    unawaited(FPGAudio.playSfx(FPGAudio.click));
                    _choose(e, c, p);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: FPGTheme.accent.withValues(alpha: .35)),
                    padding: EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: TextStyle(fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text(c.description, style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choose(RelationshipEvent e, RelationshipEventChoice c, dynamic p) async {
    final now = engine.state;
    final result = engine.worldEngine.relationshipEventsEngine.resolve(
      event: e,
      choiceId: c.id,
      p: p,
      web: engine.worldEngine.relationshipWebEngine,
      absoluteDay: day,
      year: now.year,
      month: now.month,
      day: now.day,
    );
    if (result != null) {
      engine.worldEngine.lastDayEvents.add(result);
      engine.worldEngine.worldEventHistory.add(result);
      engine.worldEngine.worldEventEngine.absorbExternalEvents([result]);
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?.description ?? 'Ta decyzja nie jest już dostępna.')),
      );
    }
  }

  Widget _resolved(RelationshipEvent e) {
    final choice = e.choices.where((c) => c.id == e.chosenId).firstOrNull;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      leading: Icon(Icons.check_circle_outline, color: FPGTheme.accent),
      title: Text(e.title, style: TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('Wybrano: ${choice?.title ?? e.chosenId ?? '—'}', style: TextStyle(color: FPGTheme.muted)),
    );
  }
}
