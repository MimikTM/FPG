import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/game_engine.dart';
import '../core/beta_diagnostics.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';
import 'league_table_screen.dart';
import 'lifestyle_screen.dart';
import 'manager_screen.dart';
import 'match_screen.dart';
import 'news_screen.dart';
import 'player_development_screen.dart';
import 'player_profile_screen.dart';
import 'team_screen.dart';
import 'club_screen.dart';
import 'training_screen.dart';
import 'transfers_screen.dart';
import 'career_decision_center_screen.dart';
import 'career_storylines_screen.dart';
import 'relationship_web_screen.dart';
import 'relationship_actions_screen.dart';
import 'relationship_events_screen.dart';
import 'season_overview_screen.dart';
import 'settings_screen.dart';
import '../widgets/fpg_animated.dart';

class CareerHomeScreen extends StatefulWidget {
  final GameEngine engine;
  CareerHomeScreen({super.key, required this.engine});
  @override State<CareerHomeScreen> createState() => _CareerHomeScreenState();
}

class _CareerHomeScreenState extends State<CareerHomeScreen> with WidgetsBindingObserver {
  GameEngine get engine => widget.engine;
  int tab = 0;
  bool _advancingDay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FPGAudio.playMusic(FPGAudio.careerMusic);
  }

  @override
  void dispose() {
    FPGAudio.stopMusic();
    WidgetsBinding.instance.removeObserver(this);
    // Best effort final save when this career screen is removed.
    widget.engine.saveWorld();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.engine.saveWorld();
    }
  }

  void open(Widget page) async {
    await Navigator.push(context, FPGPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final player = engine.careerPlayer;
    if (player == null || player.contract == null) {
      return Scaffold(body: Center(child: Text('Brak aktywnej kariery.')));
    }
    final contract = player.contract!;
    final clubMatches = engine.clubs.where((c) => c.id == player.clubId).toList();
    if (clubMatches.isEmpty) {
      return Scaffold(
        body: Center(child: Text('Nie znaleziono klubu zawodnika.')),
      );
    }
    final club = clubMatches.first;

    final pages = [
      _dashboard(player, contract, club),
      _worldHub(),
      _careerHub(),
      ClubScreen(engine: engine),
      _profile(player, club),
    ];

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(gradient: LinearGradient(colors: [FPGTheme.accent, FPGTheme.secondary]), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.sports_soccer, color: FPGTheme.isLight ? Colors.white : Colors.black, size: 20)),
          SizedBox(width: 10),
          Text('FPG'),
        ]),
        actions: [
          IconButton(icon: Icon(Icons.settings_outlined), tooltip: 'Ustawienia', onPressed: () {
            HapticFeedback.lightImpact();
            open(SettingsScreen(engine: engine));
          }),
          IconButton(icon: Icon(Icons.save_outlined), onPressed: () async {
            HapticFeedback.lightImpact();
            final ok = await engine.saveWorld();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Gra zapisana' : 'Błąd zapisu')));
          }),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
        ),
      ),
      bottomNavigationBar: _pillNavBar(),
    );
  }

  // ==========================================================
  // DOLNY PASEK NAWIGACJI — pływająca "pigułka" z okrągłymi
  // ikonami, w stylu referencyjnych screenów (aktywna zakładka
  // podświetlona kółkiem w kolorze akcentu).
  // ==========================================================

  Widget _pillNavBar() {
    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'Start'),
      (Icons.public_outlined, Icons.public, 'Świat'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Kariera'),
      (Icons.shield_outlined, Icons.shield_rounded, 'Klub'),
      (Icons.person_outline, Icons.person_rounded, 'Profil'),
    ];
    return SafeArea(
      minimum: EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 66,
        padding: EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: FPGTheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: FPGTheme.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: FPGTheme.isLight ? .08 : .35), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final selected = i == tab;
            final (outline, filled, label) = items[i];
            return InkWell(
              customBorder: CircleBorder(),
              onTap: () {
                if (i != tab) HapticFeedback.selectionClick();
                setState(() => tab = i);
              },
              child: AnimatedContainer(
                duration: Duration(milliseconds: 180),
                width: selected ? 52 : 44,
                height: selected ? 52 : 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? LinearGradient(colors: [FPGTheme.accent, FPGTheme.secondary])
                      : null,
                  color: selected ? null : Colors.transparent,
                  boxShadow: selected ? [BoxShadow(color: FPGTheme.accent.withValues(alpha: .45), blurRadius: 14, spreadRadius: 1)] : [],
                ),
                child: Icon(
                  selected ? filled : outline,
                  color: selected ? (FPGTheme.isLight ? Colors.white : Colors.black) : FPGTheme.muted,
                  size: 22,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _dashboard(dynamic player, dynamic contract, dynamic club) => ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
    _hero(player, club),
    SizedBox(height: 12),
    _leaguePositionCard(club),
    SizedBox(height: 12),
    _careerStatusStrip(player, club),
    SizedBox(height: 18),
    _section('NAJBLIŻSZY MECZ'),
    _matchCard(club),
    SizedBox(height: 12),
    _continueDayCard(),
    SizedBox(height: 18),
    _section('KONTRAKT I WIZERUNEK'),
    _shirtNumberCard(player),
    SizedBox(height: 18),
    _section('FORMA I STATUS'),
    Row(children: [Expanded(child: _metric('FORMA', '${player.form}', Icons.trending_up)), SizedBox(width: 10), Expanded(child: _metric('KONDYCJA', '${player.fitness}', Icons.bolt)), SizedBox(width: 10), Expanded(child: _metric('MORALE', '${player.morale}', Icons.mood))]),
    SizedBox(height: 18),
    _section('DZISIAJ'),
    _todayActionBanner(),
    _actionTile(Icons.fitness_center, 'Trening', engine.dailyCareerActionConsumed ? 'Dzisiejsza akcja została już wykonana' : 'Popraw rozwój i walcz o skład', engine.dailyCareerActionConsumed ? null : () => open(TrainingScreen(engine: engine))),
    _actionTile(Icons.newspaper_outlined, 'FPG News', 'Co dzieje się w świecie futbolu', () => open(NewsScreen(engine: engine))),
    _actionTile(Icons.hub_outlined, 'Centrum decyzji', 'Transfery, kontrakty, media i sponsorzy', () => open(CareerDecisionCenterScreen(engine: engine))),
  ]);



  Widget _leaguePositionCard(dynamic club) {
    final table = engine.leagueEngine.table;
    final index = table.indexWhere((s) => s.clubId == club.id);
    final position = index < 0 ? 0 : index + 1;
    final standing = index < 0 ? null : table[index];
    final league = engine.leagues.firstWhere((l) => l.id == club.leagueId);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: FPGDecor.glowCard(accent: true),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(gradient: LinearGradient(colors: [FPGTheme.accent, FPGTheme.secondary]), borderRadius: BorderRadius.circular(15)), child: Center(child: position > 0 ? CountUpNumber(value: position, suffix: '.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: FPGTheme.isLight ? Colors.white : Colors.black)) : Text('—', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: FPGTheme.isLight ? Colors.white : Colors.black)))),
        SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(league.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: FPGTheme.muted)),
          SizedBox(height: 3),
          Text(position > 0 ? '$position. miejsce w tabeli' : 'Pozycja zostanie ustalona', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          if (standing != null) Text('${standing.points} pkt • ${standing.played} meczów', style: TextStyle(color: FPGTheme.muted, fontSize: 11)),
        ])),
        Icon(Icons.chevron_right_rounded),
      ]),
    );
  }


  Widget _shirtNumberCard(dynamic player) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final current = player.shirtNumber as int;
        final value = await showDialog<int>(context: context, builder: (context) {
          int selected = current;
          return StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
            title: Text('NUMER KOSZULKI'),
            content: DropdownButtonFormField<int>(
              initialValue: selected,
              decoration: InputDecoration(labelText: 'Wybierz numer'),
              items: List.generate(99, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text('#$n'))).toList(),
              onChanged: (n) => setDialogState(() => selected = n ?? current),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('ANULUJ')), FilledButton(onPressed: () => Navigator.pop(context, selected), child: Text('ZAPISZ'))],
          ));
        });
        if (value != null) {
          engine.configureCareerContract(years: player.contract?.yearsRemaining ?? 3, weeklySalary: player.contract?.weeklySalary ?? 0, shirtNumber: value);
          await engine.saveWorld();
          if (mounted) setState(() {});
        }
      },
      child: Padding(padding: EdgeInsets.all(15), child: Row(children: [
        Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: FPGTheme.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: Text('#${player.shirtNumber}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: FPGTheme.accent))),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Numer koszulki', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('Możesz uzgodnić nowy numer z klubem.', style: TextStyle(color: FPGTheme.muted, fontSize: 11))])),
        Icon(Icons.edit_rounded, size: 18),
      ])),
    ),
  );

  Widget _careerStatusStrip(dynamic player, dynamic club) {
    final season = engine.currentSeason;
    final next = engine.nextCareerFixture;
    final matchText = next == null
        ? 'Brak kolejnego meczu'
        : engine.careerHasMatchToday
            ? 'Mecz dzisiaj'
            : 'Najbliższy mecz za ${_daysUntil(next)} dni';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: FPGDecor.glowCard(),
      child: Row(children: [
        Icon(Icons.calendar_month_rounded, size: 18, color: FPGTheme.accent),
        SizedBox(width: 10),
        Expanded(child: Text('SEZON $season  •  $matchText', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FPGTheme.muted))),
        Text('DZIŚ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: FPGTheme.accent.withValues(alpha: .9))),
      ]),
    );
  }

  int _daysUntil(dynamic fixture) {
    try {
      final today = DateTime(engine.gameState.year, engine.gameState.month, engine.gameState.day).difference(DateTime(engine.gameState.year, 1, 1)).inDays;
      final targetDate = DateTime(fixture.year, fixture.month, fixture.day);
      final todayDate = DateTime(engine.gameState.year, engine.gameState.month, engine.gameState.day);
      return targetDate.difference(DateTime(todayDate.year, todayDate.month, todayDate.day)).inDays.clamp(0, 999);
    } catch (_) {
      return 0;
    }
  }

  Widget _todayActionBanner() {
    final consumed = engine.dailyCareerActionConsumed;
    final label = engine.dailyCareerAction == 'training'
        ? 'TRENING WYKONANY'
        : engine.dailyCareerAction == 'match'
            ? 'MECZ ROZEGRANY'
            : 'WYBIERZ AKCJĘ DNIA';
    return Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(children: [
          PulsingIcon(icon: consumed ? Icons.check_circle : Icons.today, color: FPGTheme.accent, pulse: !consumed, size: 22),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 2),
          Text(
            consumed
                ? 'Decyzja zapisana na dzisiejszej dacie symulacji.'
                : 'Wybierz jedną główną akcję przed przejściem dalej.',
            style: TextStyle(color: FPGTheme.muted, fontSize: 10),
          ),
        ])),
        if (consumed) Text('GOTOWE', style: TextStyle(color: FPGTheme.muted, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _worldHub() => ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
    _title('Świat futbolu', 'Świat działa również bez Ciebie.'),
    _worldCard(Icons.newspaper, 'Wiadomości', 'Transfery, trenerzy, kryzysy i wydarzenia', () => open(NewsScreen(engine: engine))),
    _worldCard(Icons.swap_horiz, 'Transfery', 'Rynek zawodników i ruchy klubów', () => open(TransfersScreen(engine: engine))),
    _worldCard(Icons.leaderboard, 'Tabele', 'Formy lig i walka o awans', () => open(LeagueTableScreen(engine: engine))),
    _worldCard(Icons.shield_outlined, 'Klub', 'Kadra, OVR, budżet i skład meczowy', () => open(ClubScreen(engine: engine))),
    _worldCard(Icons.groups, 'Relacje z drużyną', 'Szatnia, atmosfera i integracja', () => open(TeamScreen(engine: engine))),
    _worldCard(Icons.manage_accounts, 'Trener', 'Zaufanie, decyzje i hierarchia', () => open(ManagerScreen(engine: engine))),
  ]);

  Widget _careerHub() => ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
    _title('Kariera', 'Decyzje, które zmieniają Twoją ścieżkę.'),
    _worldCard(Icons.sports_soccer, 'Mecz', 'Rozegraj kolejkę i wpływaj na wynik', () => open(MatchScreen(engine: engine))),
    _worldCard(Icons.emoji_events_outlined, 'Sezon', 'Tabela, cel klubu i postęp sezonu', () => open(SeasonOverviewScreen(engine: engine))),
    _worldCard(Icons.fitness_center, 'Trening', 'Rozwijaj atrybuty i potencjał', () => open(TrainingScreen(engine: engine))),
    _worldCard(Icons.auto_graph, 'Rozwój', 'OVR, potencjał i progres', () => open(PlayerDevelopmentScreen(engine: engine))),
    _worldCard(Icons.favorite, 'Życie', 'Relacje i decyzje poza boiskiem', () => open(LifestyleScreen(engine: engine))),
    _worldCard(Icons.swap_horiz, 'Transfery', 'Zainteresowanie klubów i negocjacje', () => open(TransfersScreen(engine: engine))),
    _worldCard(Icons.hub_outlined, 'Centrum decyzji', 'Wszystkie ważne decyzje kariery w jednym miejscu', () => open(CareerDecisionCenterScreen(engine: engine))),
    _worldCard(Icons.auto_stories_outlined, 'Historie kariery', 'Wielostopniowe wydarzenia i ich zakończenia', () => open(CareerStorylinesScreen(engine: engine))),
    _worldCard(Icons.hub_outlined, 'Sieć relacji', 'Agent, trener, klub, kibice i media', () => open(RelationshipWebScreen(engine: engine))),
    _worldCard(Icons.bolt_outlined, 'Akcje relacji', 'Wykorzystaj zaufanie i odblokowane możliwości', () => open(RelationshipActionsScreen(engine: engine))),
    _worldCard(Icons.forum_outlined, 'Wydarzenia relacji', 'Rozmowy, telefony i sytuacje wymagające decyzji', () => open(RelationshipEventsScreen(engine: engine))),
  ]);

  Widget _profile(dynamic player, dynamic club) => ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
    _hero(player, club),
    SizedBox(height: 16),
    _section('STATYSTYKI KARIERY'),
    Card(child: Padding(padding: EdgeInsets.all(18), child: Column(children: [
      _row('Występy', '${player.careerAppearances}'),
      _row('Gole', '${player.careerGoals}'),
      _row('Asysty', '${player.careerAssists}'),
      _row('Wartość', '${(player.contract?.marketValue ?? 0).toStringAsFixed(0)} zł'),
    ]))),
    SizedBox(height: 16),
    _worldCard(Icons.person, 'Pełny profil', 'Atrybuty, kontrakt i historia zawodnika', () => open(PlayerProfileScreen(engine: engine))),
  ]);

  Widget _hero(dynamic player, dynamic club) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: FPGDecor.heroCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.fullName,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      club.name,
                      style: TextStyle(color: FPGTheme.muted),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '${_position(player.position)} • ${player.age} lat',
                      style: TextStyle(color: FPGTheme.textPrimary.withValues(alpha: .7)),
                    ),
                  ],
                ),
              ),
              OvrRing(value: player.overall as int, size: 76, color: FPGTheme.accent),
            ],
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _mini('FORMA', '${player.form}')),
              SizedBox(width: 8),
              Expanded(child: _mini('MORALE', '${player.morale}')),
              SizedBox(width: 8),
              Expanded(
                child: _mini(
                  'NR',
                  '#${player.contract?.squadNumber ?? '-'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matchCard(dynamic club) {
    final fixture = engine.nextCareerFixture;
    if (fixture == null) {
      return Card(child: Padding(padding: EdgeInsets.all(18), child: Row(children: [
        Icon(Icons.event_available, color: FPGTheme.accent), SizedBox(width: 12),
        Expanded(child: Text('Brak kolejnych spotkań w terminarzu.', style: TextStyle(fontWeight: FontWeight.w700))),
      ])));
    }
    final isHome = fixture.homeClubId == club.id;
    final opponentId = isHome ? fixture.awayClubId : fixture.homeClubId;
    final opponent = engine.clubs.firstWhere((c) => c.id == opponentId, orElse: () => club);
    final today = engine.careerHasMatchToday;
    final date = '${fixture.day.toString().padLeft(2, '0')}.${fixture.month.toString().padLeft(2, '0')}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: today ? () => open(MatchScreen(engine: engine)) : null,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: FPGTheme.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.sports_soccer, color: FPGTheme.accent)),
            SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(today ? 'DZISIAJ' : 'NASTĘPNY MECZ • $date', style: TextStyle(color: FPGTheme.muted, fontSize: 11, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('${isHome ? 'DOM' : 'WYJAZD'} • ${opponent.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(today ? 'Rozegraj mecz' : 'Mecz pojawi się w centrum dnia', style: TextStyle(color: FPGTheme.muted)),
            ])),
            Icon(today ? Icons.play_arrow_rounded : Icons.lock_clock, size: 22, color: today ? FPGTheme.accent : FPGTheme.muted),
          ]),
        ),
      ),
    );
  }

  Future<void> _advanceDay() async {
    if (_advancingDay) return;
    HapticFeedback.mediumImpact();
    // Paint the loading state on its own frame BEFORE the heavy synchronous
    // simulation call below runs, so the tap always gets an immediate visual
    // response instead of the UI going unresponsive with no feedback.
    setState(() => _advancingDay = true);
    await Future.delayed(Duration.zero);
    try {
      final report = engine.advanceSimulationDay();
      if (mounted) {
        final summary = engine.worldEngine.lastDaySummary;
        final seasonText = report.seasonAdvanced ? ' • NOWY SEZON' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            '${report.dateString} • Świat: ${summary['matches'] ?? 0} meczów, ${summary['events'] ?? 0} wydarzeń$seasonText',
          )),
        );
      }
    } catch (e, stack) {
      // Next-day failures must be visible to the player but also captured for
      // Open Beta diagnosis. The game stays on the current screen instead of
      // allowing an unhandled exception to terminate the session.
      unawaited(BetaDiagnostics.record(
        type: 'next_day_error',
        message: e.toString(),
        stack: stack.toString(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się przetworzyć dnia. Spróbuj ponownie lub prześlij diagnostykę.')),
        );
      }
    } finally {
      if (mounted) setState(() => _advancingDay = false);
    }
  }

  Widget _continueDayCard() {
    final blockedByMatch = engine.careerHasMatchToday;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _advancingDay
            ? null
            : (blockedByMatch ? () => open(MatchScreen(engine: engine)) : _advanceDay),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: FPGTheme.surface2,
                borderRadius: BorderRadius.circular(13),
              ),
              child: _advancingDay
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: FPGTheme.accent),
                    )
                  : Icon(
                      blockedByMatch ? Icons.sports_soccer : Icons.fast_forward_rounded,
                      color: FPGTheme.accent,
                    ),
            ),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _advancingDay ? 'PRZETWARZANIE DNIA...' : (blockedByMatch ? 'ROZEGRAJ MECZ' : 'KONTYNUUJ DZIEŃ'),
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                _advancingDay
                    ? 'Symulowanie świata w toku...'
                    : (blockedByMatch
                        ? 'Nie można przejść dalej bez rozegrania dzisiejszego spotkania'
                        : 'Przejdź do kolejnego dnia kariery'),
                style: TextStyle(color: FPGTheme.muted, fontSize: 12),
              ),
            ])),
            if (!_advancingDay)
              Icon(
                blockedByMatch ? Icons.play_arrow_rounded : Icons.arrow_forward_ios,
                size: 18,
                color: FPGTheme.accent,
              ),
          ]),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Card(child: Padding(padding: EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: FPGTheme.accent), SizedBox(height: 10), CountUpNumber(value: int.tryParse(value) ?? 0, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(label, style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w700))])));
  Widget _mini(String label, String value) => Container(padding: EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: FPGTheme.surface2, borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(value, style: TextStyle(fontWeight: FontWeight.w900)), Text(label, style: TextStyle(color: FPGTheme.muted, fontSize: 9))]));
  Widget _section(String t) => Padding(padding: EdgeInsets.only(bottom: 10), child: Text(t, style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: FPGTheme.muted)));
  Widget _title(String t, String sub) => Padding(padding: EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text(sub, style: TextStyle(color: FPGTheme.muted))]));
  Widget _worldCard(IconData icon, String title, String sub, VoidCallback? onTap) => Card(
    margin: EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: FPGTheme.accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: FPGTheme.accent)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(sub, style: TextStyle(color: FPGTheme.muted)),
      trailing: Icon(Icons.chevron_right),
      onTap: onTap == null ? null : () { HapticFeedback.selectionClick(); onTap(); },
    ),
  );
  Widget _actionTile(IconData icon, String title, String sub, VoidCallback? onTap) => _worldCard(icon, title, sub, onTap);
  Widget _row(String a, String b) => Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a, style: TextStyle(color: FPGTheme.muted)), Text(b, style: TextStyle(fontWeight: FontWeight.w800))]));
  String _position(dynamic p) => p.toString().split('.').last.toUpperCase();
}
