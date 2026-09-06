import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/game_engine.dart';
import '../models/club.dart';
import 'career_start_screen.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';
import '../widgets/fpg_animated.dart';

class ClubSelectionScreen extends StatefulWidget {
  final GameEngine engine;
  ClubSelectionScreen({super.key, required this.engine});

  @override
  State<ClubSelectionScreen> createState() => _ClubSelectionScreenState();
}

class _ClubSelectionScreenState extends State<ClubSelectionScreen> with SingleTickerProviderStateMixin {
  GameEngine get engine => widget.engine;
  bool _joining = false;
  String? _joiningClubId;

  late final AnimationController _entrance;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  }

  @override
  void dispose() { _entrance.dispose(); super.dispose(); }

  List<Club> get clubs {
    final result = engine.careerStartClubs.toList();
    result.sort((a, b) {
      final la = engine.leagues.firstWhere((l) => l.id == a.leagueId).level;
      final lb = engine.leagues.firstWhere((l) => l.id == b.leagueId).level;
      if (la != lb) return la.compareTo(lb);
      return b.overall.compareTo(a.overall);
    });
    return result;
  }

  String description(Club club) {
    if (club.overall >= 72) return 'Faworyt ligi • duża konkurencja o skład';
    if (club.overall >= 65) return 'Ambitny klub • walka o regularne minuty';
    if (club.overall >= 60) return 'Rozwój młodego zawodnika • realna droga do XI';
    return 'Słabszy klub • większa szansa na szybki debiut';
  }

  Future<void> selectClub(Club club) async {
    if (_joining) return;
    HapticFeedback.mediumImpact();
    unawaited(FPGAudio.playSfx(FPGAudio.click));
    setState(() { _joining = true; _joiningClubId = club.id; });

    engine.assignPlayerToClub(club.id);
    // Do tego momentu kariera istniała tylko w pamięci — to pierwsza chwila,
    // w której ma sens do zapisania (zawodnik + klub). Bez tego świeżo
    // utworzona kariera znikała, jeśli gracz nie zagrał od razu meczu.
    final saved = await engine.saveWorld();
    if (!mounted) return;
    if (!saved) {
      HapticFeedback.heavyImpact();
      unawaited(FPGAudio.playSfx(FPGAudio.error));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kariera utworzona, ale autozapis się nie udał.')),
      );
      setState(() { _joining = false; _joiningClubId = null; });
      return;
    }
    unawaited(FPGAudio.playSfx(FPGAudio.success));
    if (!mounted) return;
    Navigator.pushReplacement(context, FPGPageRoute(builder: (_) => CareerStartScreen(engine: engine)));
  }

  @override
  Widget build(BuildContext context) {
    final all = clubs;
    final grouped = <String, List<Club>>{};
    for (final c in all) {
      final league = engine.leagues.firstWhere((l) => l.id == c.leagueId);
      grouped.putIfAbsent(league.name, () => []).add(c);
    }
    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(title: Text('WYBÓR KLUBU')),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Container(padding: EdgeInsets.all(20), decoration: FPGDecor.heroCard(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PIERWSZY KROK', style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                SizedBox(height: 7), Text('Wybierz środowisko swojej kariery', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 6), Text('Masz do wyboru pełną polską piramidę ligową. Poziom ligi wpływa na rywali, presję, rozwój i drogę awansu.', style: TextStyle(color: FPGTheme.muted)),
              ])),
              SizedBox(height: 18),
              for (final entry in grouped.entries) ...[
                Text(entry.key.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: FPGTheme.muted)),
                SizedBox(height: 10),
                ...entry.value.map((club) => _clubCard(club)),
                SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _clubCard(Club club) {
    final isThisJoining = _joining && _joiningClubId == club.id;
    final dimmed = _joining && !isThisJoining;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? .4 : 1,
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        decoration: FPGDecor.glowCard(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _joining ? null : () => selectClub(club),
            child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(club.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), _ovr(club.overall)]),
              SizedBox(height: 6),
              Text(description(club), style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
              SizedBox(height: 13),
              Row(children: [
                _small('BUDŻET', '${(club.budget / 1000000).toStringAsFixed(1)} mln'),
                SizedBox(width: 8),
                _small('REPUTACJA', '${club.reputation}'),
                Spacer(),
                isThisJoining
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: FPGTheme.accent))
                    : Icon(Icons.arrow_forward_rounded, size: 20, color: FPGTheme.muted),
              ]),
            ])),
          ),
        ),
      ),
    );
  }

  Widget _ovr(int value) => Container(width: 52, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: FPGTheme.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)), child: Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: FPGTheme.accent)));
  Widget _small(String label, String value) => Container(padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: FPGTheme.surface2, borderRadius: BorderRadius.circular(9)), child: Text('$label  $value', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: FPGTheme.muted)));
}
