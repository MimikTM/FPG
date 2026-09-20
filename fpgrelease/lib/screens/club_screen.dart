import 'package:flutter/material.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../models/player.dart';
import '../widgets/fpg_animated.dart';

/// Centrum klubu: kadra, skład meczowy, OVR, budżet i podstawowe informacje
/// zarządcze. To osobny widok od relacji z szatnią.
class ClubScreen extends StatefulWidget {
  final GameEngine engine;
  const ClubScreen({super.key, required this.engine});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> with SingleTickerProviderStateMixin {
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

  ClubViewStatus _status(Player p, List<Player> sorted) {
    final index = sorted.indexOf(p);
    if (p.injured) return ClubViewStatus.injured;
    if (index < 11) return ClubViewStatus.starting;
    if (index < 18) return ClubViewStatus.bench;
    return ClubViewStatus.out;
  }

  @override
  Widget build(BuildContext context) {
    final career = engine.careerPlayer;
    if (career == null || career.clubId == null) {
      return const Scaffold(body: Center(child: Text('Brak aktywnego klubu.')));
    }
    final clubs = engine.clubs.where((c) => c.id == career.clubId).toList();
    if (clubs.isEmpty) {
      return const Scaffold(body: Center(child: Text('Nie znaleziono klubu.')));
    }
    final club = clubs.first;
    final squad = engine.players.where((p) => p.clubId == club.id).toList()
      ..sort((a, b) {
        final score = _selectionScore(b).compareTo(_selectionScore(a));
        return score != 0 ? score : a.position.index.compareTo(b.position.index);
      });

    final available = squad.where((p) => !p.injured).toList();
    final starters = available.take(11).toList();
    final bench = available.skip(11).take(7).toList();
    final out = [
      ...available.skip(18),
      ...squad.where((p) => p.injured),
    ];
    final league = engine.leagues.where((l) => l.id == club.leagueId).firstOrNull;

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(title: const Text('KLUB'), backgroundColor: FPGTheme.bg),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrance,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _clubHeader(club, league?.name ?? club.leagueId),
              const SizedBox(height: 14),
              _summary(club, squad.length),
              const SizedBox(height: 18),
              _section('PODSTAWOWY SKŁAD', starters, ClubViewStatus.starting),
              const SizedBox(height: 14),
              _section('ŁAWKA REZERWOWYCH', bench, ClubViewStatus.bench),
              if (out.isNotEmpty) ...[
                const SizedBox(height: 14),
                _section('POZA KADRĄ', out, ClubViewStatus.out),
              ],
              const SizedBox(height: 18),
              _clubDetails(club),
            ],
          ),
        ),
      ),
    );
  }

  double _selectionScore(Player p) {
    final fitness = (p.fitness - 70) * .12;
    final form = (p.form - 70) * .10;
    final fatigue = p.fatigue * .08;
    final morale = (p.morale - 70) * .04;
    return p.overall + fitness + form + morale - fatigue;
  }

  Widget _clubHeader(dynamic club, String league) => Container(
    padding: const EdgeInsets.all(20),
    decoration: FPGDecor.heroCard(),
    child: Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [FPGTheme.accent, FPGTheme.secondary]),
            borderRadius: BorderRadius.circular(19),
          ),
          child: const Icon(Icons.shield_rounded, size: 34),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(club.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('$league • ${club.country}', style: TextStyle(color: FPGTheme.muted)),
            const SizedBox(height: 8),
            Text('Trener: ${club.managerName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
        _bigMetric('${club.overall}', 'OVR'),
      ],
    ),
  );

  Widget _bigMetric(String value, String label) => Column(
    children: [
      Container(width: 58, height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: FPGTheme.accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(17)), child: CountUpNumber(value: int.tryParse(value) ?? 0, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: FPGTheme.accent))),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: FPGTheme.muted)),
    ],
  );

  Widget _summary(dynamic club, int squadSize) => Container(
    decoration: FPGDecor.glowCard(),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _row('Budżet klubu', '${club.budget.toString()} zł'),
        _row('Liczba zawodników', '$squadSize'),
        _row('Reputacja', '${club.reputation}/100'),
        _row('Finanse', '${club.financialHealth}/100'),
        _row('Zaufanie zarządu', '${club.boardConfidence}/100'),
        _row('Akademia', '${club.academyQuality}/100'),
      ]),
    ),
  );

  Widget _section(String title, List<Player> players, ClubViewStatus forcedStatus) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Container(
        decoration: FPGDecor.glowCard(),
        child: Column(
          children: players.map((p) => _playerRow(p, forcedStatus)).toList(),
        ),
      ),
    ],
  );

  Widget _playerRow(Player p, ClubViewStatus forcedStatus) {
    final status = p.injured ? ClubViewStatus.injured : forcedStatus;
    final statusText = switch (status) {
      ClubViewStatus.starting => 'PODSTAWOWY',
      ClubViewStatus.bench => 'ŁAWKA',
      ClubViewStatus.out => 'POZA KADRĄ',
      ClubViewStatus.injured => 'KONTUZJA',
    };
    return ListTile(
      dense: true,
      leading: Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: FPGTheme.surface2, borderRadius: BorderRadius.circular(11)), child: Text('#${p.shirtNumber}', style: const TextStyle(fontWeight: FontWeight.w900))),
      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${_position(p.position)} • $statusText', style: TextStyle(color: FPGTheme.muted, fontSize: 11)),
      trailing: Container(width: 42, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: FPGTheme.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Text('${p.overall}', style: TextStyle(fontWeight: FontWeight.w900, color: FPGTheme.accent))),
    );
  }

  Widget _clubDetails(dynamic club) => Container(
    decoration: FPGDecor.glowCard(),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('INFORMACJE KLUBOWE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 10),
        _row('Styl trenera', club.managerStyle),
        _row('Reputacja trenera', '${club.managerReputation}/100'),
        _row('Wsparcie kibiców', '${club.fanSupport}/100'),
        _row('Stabilność', '${club.stability}/100'),
        _row('Transfery', '${club.transferActivity}/100'),
        _row('Presja zarządu', '${club.boardPressure}/100'),
        _row('Bilans sezonu', '${club.winsStreak} zwycięstw z rzędu'),
      ]),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: FPGTheme.muted))), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
  );

  String _position(PlayerPosition p) => switch (p) {
    PlayerPosition.goalkeeper => 'BR',
    PlayerPosition.defender => 'OBR',
    PlayerPosition.midfielder => 'POM',
    PlayerPosition.winger => 'SKRZYDŁO',
    PlayerPosition.striker => 'NAP',
  };
}

enum ClubViewStatus { starting, bench, out, injured }

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
