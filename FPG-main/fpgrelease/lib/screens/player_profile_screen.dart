import 'package:flutter/material.dart';

import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../widgets/fpg_animated.dart';

class PlayerProfileScreen extends StatefulWidget {
  final GameEngine engine;

  PlayerProfileScreen({
    super.key,
    required this.engine,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> with SingleTickerProviderStateMixin {
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
    final player = engine.careerPlayer;

    if (player == null) {
      return Scaffold(
        backgroundColor: FPGTheme.bg,
        appBar: AppBar(
          title: Text('PROFIL ZAWODNIKA'),
          backgroundColor: FPGTheme.bg,
        ),
        body: Center(
          child: Text(
            'Brak utworzonego zawodnika.',
            style: TextStyle(color: FPGTheme.muted),
          ),
        ),
      );
    }

    final club = player.clubId == null
        ? null
        : engine.clubs.where((club) => club.id == player.clubId).isEmpty
            ? null
            : engine.clubs.firstWhere((club) => club.id == player.clubId);

    return Scaffold(
      backgroundColor: FPGTheme.bg,

      appBar: AppBar(
        title: Text('PROFIL ZAWODNIKA'),
        backgroundColor: FPGTheme.bg,
      ),

      body: SafeArea(
        child: FadeTransition(
          opacity: _entrance,
          child: ListView(
            padding: EdgeInsets.all(16),

            children: [

              // ==================================================
              // NAGŁÓWEK — karta zawodnika w stylu FIFA/EA FC
              // ==================================================

              Container(
                padding: EdgeInsets.all(20),
                decoration: FPGDecor.heroCard(),
                child: Column(
                  children: [

                    OvrRing(
                      value: player.overall,
                      size: 92,
                      color: FPGTheme.accent,
                    ),

                    SizedBox(height: 16),

                    Text(
                      player.fullName,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: FPGTheme.textPrimary,
                      ),
                    ),

                    SizedBox(height: 6),

                    Text(
                      player.position.name.toUpperCase(),
                      style: TextStyle(
                        color: FPGTheme.muted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),

                    SizedBox(height: 12),

                    Text(
                      club?.name ?? 'BRAK KLUBU',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: FPGTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // ==================================================
              // PODSTAWOWE INFORMACJE
              // ==================================================

              _sectionTitle('INFORMACJE'),

              _infoCard([
                _infoRow('Narodowość', player.nationality),
                _infoRow('Wiek', '${player.age} lat'),
                _infoRow('Wzrost', '${player.height} cm'),
                _infoRow(
                  'Pozycja',
                  player.position.name.toUpperCase(),
                ),
                _infoRow(
                  'Numer',
                  player.shirtNumber.toString(),
                ),
                _infoRow(
                  'OVR',
                  player.overall.toString(),
                ),
                _infoRow(
                  'Potencjał',
                  player.potential.toString(),
                ),
              ]),

              SizedBox(height: 16),

              // ==================================================
              // UMIEJĘTNOŚCI — animowane paski jak w kartach FIFA
              // ==================================================

              _sectionTitle('UMIEJĘTNOŚCI'),

              _statsCard([
                AnimatedStatBar(label: 'PACE', value: player.pace, color: FPGTheme.accent),
                AnimatedStatBar(label: 'SHOOTING', value: player.shooting, color: FPGTheme.accent),
                AnimatedStatBar(label: 'PASSING', value: player.passing, color: FPGTheme.accent),
                AnimatedStatBar(label: 'DRIBBLING', value: player.dribbling, color: FPGTheme.accent),
                AnimatedStatBar(label: 'DEFENDING', value: player.defending, color: FPGTheme.accent),
                AnimatedStatBar(label: 'PHYSICAL', value: player.physical, color: FPGTheme.accent),
              ]),

              SizedBox(height: 16),

              // ==================================================
              // FORMA
              // ==================================================

              _sectionTitle('STAN ZAWODNIKA'),

              _statsCard([
                AnimatedStatBar(label: 'FORMA', value: player.form, max: 100, color: FPGTheme.secondary),
                AnimatedStatBar(label: 'KONDYCJA', value: player.fitness, max: 100, color: FPGTheme.secondary),
                AnimatedStatBar(label: 'ZMĘCZENIE', value: player.fatigue, max: 100, color: FPGTheme.secondary),
                AnimatedStatBar(label: 'MORALE', value: player.morale, max: 100, color: FPGTheme.secondary),
                AnimatedStatBar(label: 'SZCZĘŚCIE', value: player.happiness, max: 100, color: FPGTheme.secondary),
                AnimatedStatBar(label: 'TRENER', value: player.managerRelationship, max: 100, color: FPGTheme.secondary),
                AnimatedStatBar(label: 'DRUŻYNA', value: player.teamRelationship, max: 100, color: FPGTheme.secondary),
              ]),

              SizedBox(height: 16),

              // ==================================================
              // KONTRAKT
              // ==================================================

              _sectionTitle('KONTRAKT'),

              _infoCard([
                _infoRow(
                  'Klub',
                  club?.name ?? 'Brak klubu',
                ),
                _infoRow(
                  'Pensja',
                  player.contract == null
                      ? '-'
                      : '${player.contract!.weeklySalary.toStringAsFixed(0)} / tydz.',
                ),
                _infoRow(
                  'Wartość',
                  player.contract == null
                      ? '-'
                      : '${player.contract!.marketValue.toStringAsFixed(0)}',
                ),
                _infoRow(
                  'Lata kontraktu',
                  player.contract == null
                      ? '-'
                      : player.contract!.yearsRemaining.toString(),
                ),
              ]),

              SizedBox(height: 16),

              // ==================================================
              // KARIERA
              // ==================================================

              _sectionTitle('KARIERA'),

              _infoCard([
                _infoRow(
                  'Występy',
                  player.careerAppearances.toString(),
                ),
                _infoRow(
                  'Gole',
                  player.careerGoals.toString(),
                ),
                _infoRow(
                  'Asysty',
                  player.careerAssists.toString(),
                ),
              ]),

              SizedBox(height: 16),

              // ==================================================
              // STATYSTYKI MECZOWE
              // ==================================================

              _sectionTitle('STATYSTYKI MECZOWE'),

              _infoCard([
                _infoRow(
                  'Występy',
                  player.matchStats.appearances.toString(),
                ),
                _infoRow(
                  'Mecze od początku',
                  player.matchStats.starts.toString(),
                ),
                _infoRow(
                  'Wejścia z ławki',
                  player.matchStats.substituteAppearances.toString(),
                ),
                _infoRow(
                  'Minuty',
                  player.matchStats.minutes.toString(),
                ),
                _infoRow(
                  'Gole',
                  player.matchStats.goals.toString(),
                ),
                _infoRow(
                  'Asysty',
                  player.matchStats.assists.toString(),
                ),
                _infoRow(
                  'Żółte kartki',
                  player.matchStats.yellowCards.toString(),
                ),
                _infoRow(
                  'Czerwone kartki',
                  player.matchStats.redCards.toString(),
                ),
                _infoRow(
                  'Strzały',
                  player.matchStats.shots.toString(),
                ),
                _infoRow(
                  'Strzały celne',
                  player.matchStats.shotsOnTarget.toString(),
                ),
                _infoRow(
                  'Kluczowe podania',
                  player.matchStats.keyPasses.toString(),
                ),
                _infoRow(
                  'Udane dryblingi',
                  player.matchStats.successfulDribbles.toString(),
                ),
                _infoRow(
                  'Średnia ocena',
                  player.matchStats.averageRating
                      .toStringAsFixed(2),
                ),
              ]),

              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TYTUŁ SEKCJI
  // ============================================================

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
      ),

      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: FPGTheme.textPrimary,
        ),
      ),
    );
  }

  // ============================================================
  // KARTA INFORMACJI
  // ============================================================

  Widget _infoCard(
    List<Widget> children,
  ) {
    return Container(
      decoration: FPGDecor.glowCard(),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  // ============================================================
  // WIERSZ INFORMACJI
  // ============================================================

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 7,
      ),

      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [
          Text(
            label,
            style: TextStyle(
              color: FPGTheme.muted,
            ),
          ),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: FPGTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATYSTYKA
  // ============================================================

  Widget _statsCard(
    List<Widget> children,
  ) {
    return Container(
      decoration: FPGDecor.glowCard(),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}
