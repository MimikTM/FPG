import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/game_engine.dart';
import '../simulation/season_overview_engine.dart';
import '../core/fpg_theme.dart';
import '../widgets/fpg_animated.dart';

class SeasonOverviewScreen extends StatefulWidget {
  final GameEngine engine;
  SeasonOverviewScreen({super.key, required this.engine});

  @override
  State<SeasonOverviewScreen> createState() => _SeasonOverviewScreenState();
}

class _SeasonOverviewScreenState extends State<SeasonOverviewScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final overview = SeasonOverviewEngine().build(engine);
    final club = engine.careerClub;
    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(title: Text('Sezon'), backgroundColor: FPGTheme.bg),
      body: FadeTransition(
        opacity: _entrance,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _hero(overview, club?.name ?? 'Brak klubu'),
            SizedBox(height: 14),
            _card('CEL ZARZĄDU', overview.objective, Icons.flag_rounded),
            SizedBox(height: 12),
            Container(
              decoration: FPGDecor.glowCard(),
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('POSTĘP SEZONU', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, color: FPGTheme.textPrimary)),
                  SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: overview.seasonProgress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: FPGTheme.surface2, color: FPGTheme.accent),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('${overview.completedMatches} rozegranych • ${overview.remainingMatches} pozostało', style: TextStyle(color: FPGTheme.muted)),
                ]),
              ),
            ),
            SizedBox(height: 12),
            Container(
              decoration: FPGDecor.glowCard(),
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(children: [
                  _row('Pozycja', overview.position == 0 ? '—' : '${overview.position}. / ${overview.clubCount}'),
                  _row('Punkty', '${overview.standing.points}'),
                  _row('Bilans', '${overview.standing.wins}-${overview.standing.draws}-${overview.standing.losses}'),
                  _row('Bramki', '${overview.standing.goalsFor}:${overview.standing.goalsAgainst}'),
                  _row('Różnica', '${overview.standing.goalDifference >= 0 ? '+' : ''}${overview.standing.goalDifference}'),
                ]),
              ),
            ),
            SizedBox(height: 12),
            Container(
              decoration: FPGDecor.glowCard(accent: overview.remainingMatches == 0),
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(overview.remainingMatches == 0 ? Icons.emoji_events_rounded : overview.objectiveMet ? Icons.check_circle : Icons.trending_up, color: overview.remainingMatches == 0 ? Colors.amber : overview.objectiveMet ? Colors.greenAccent : FPGTheme.muted),
                    SizedBox(width: 12),
                    Expanded(child: Text(
                      overview.remainingMatches == 0 ? 'SEZON ZAKOŃCZONY — wynik został zapisany.' : overview.objectiveMet ? 'Cel jest obecnie realizowany.' : 'Cel jest jeszcze poza zasięgiem — sezon trwa.',
                      style: TextStyle(fontWeight: FontWeight.w800, color: FPGTheme.textPrimary),
                    )),
                  ]),
                  if (overview.remainingMatches == 0) ...[
                    SizedBox(height: 14),
                    SizedBox(width: double.infinity, child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        try {
                          final days = engine.finishCompletedSeason();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Okres przejściowy zakończony po $days dniach. Rozpoczęto przygotowanie kolejnego sezonu.')));
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
                        }
                      },
                      icon: Icon(Icons.fast_forward_rounded),
                      label: Text('ZAMKNIJ SEZON I PRZEJDŹ DALEJ'),
                    )),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(SeasonOverview o, String club) => Container(
    padding: EdgeInsets.all(22),
    decoration: FPGDecor.heroCard(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${o.season}/${o.season + 1}', style: TextStyle(color: FPGTheme.muted, fontWeight: FontWeight.w700)),
      SizedBox(height: 6),
      Text(club, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary)),
      SizedBox(height: 14),
      Row(children: [
        o.position == 0
            ? Text('—', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary))
            : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                CountUpNumber(value: o.position, style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary)),
                Padding(padding: EdgeInsets.only(bottom: 6), child: Text('.', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary))),
              ]),
        SizedBox(width: 12),
        Text('miejsce w lidze', style: TextStyle(color: FPGTheme.muted)),
      ]),
    ]),
  );

  Widget _card(String title, String value, IconData icon) => Container(
    decoration: FPGDecor.glowCard(),
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Row(children: [
        Icon(icon, color: FPGTheme.accent),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary)),
        ])),
      ]),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 7),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: FPGTheme.muted)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: FPGTheme.textPrimary)),
    ]),
  );
}
