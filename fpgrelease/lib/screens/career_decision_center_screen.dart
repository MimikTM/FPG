import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';
import '../models/contract_negotiation.dart';
import '../models/player.dart';
import '../models/player_career.dart';
import '../models/transfer_negotiation.dart';
import 'career_storylines_screen.dart';
import '../widgets/fpg_animated.dart';

/// V19.0 — Career Decision Center.
///
/// Jedno centrum zbiera najważniejsze decyzje kariery z istniejących systemów
/// świata: transfery, kontrakty, media i komercję. Nie tworzy osobnego świata —
/// jest tylko wspólną warstwą decyzji nad istniejącymi silnikami.
class CareerDecisionCenterScreen extends StatefulWidget {
  final GameEngine engine;
  CareerDecisionCenterScreen({super.key, required this.engine});

  @override
  State<CareerDecisionCenterScreen> createState() => _CareerDecisionCenterScreenState();
}

class _CareerDecisionCenterScreenState extends State<CareerDecisionCenterScreen> with SingleTickerProviderStateMixin {
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

  PlayerCareer? get _careerPlayer => engine.careerPlayer;

  Player? get _worldPlayer {
    final career = engine.careerPlayer;
    if (career == null) return null;
    for (final p in engine.players) {
      if (p.id == career.id) return p;
    }
    return engine.careerWorldBridge.projection;
  }

  List<TransferNegotiation> get _transfers {
    try {
      final p = _worldPlayer;
      if (p == null) return [];
      return engine.worldEngine.worldSimulation4Engine.transferNegotiationV2Engine.activeForPlayer(p.id);
    } catch (_) {
      return [];
    }
  }

  List<ContractNegotiation> get _contracts {
    try {
      final p = _worldPlayer;
      if (p == null) return [];
      return engine.worldEngine.worldSimulation4Engine.contractNegotiationEngine.activeForPlayer(p.id);
    } catch (_) {
      return [];
    }
  }

  void _refreshCareer() {
    if (!mounted) return;
    try {
      final career = engine.careerPlayer;
      if (career != null) {
        engine.careerWorldBridge.attach(career: career, worldPlayers: engine.players, clubs: engine.clubs);
        engine.careerWorldBridge.pullWorldState(career, worldPlayers: engine.players, clubs: engine.clubs);
      }
      setState(() {});
    } catch (e) {
      _toast('Nie udało się odświeżyć Centrum Decyzji. Spróbuj ponownie.');
    }
  }

  void _transferDecision(TransferNegotiation n, String decision) {
    bool ok = false;
    try {
      ok = engine.worldEngine.worldSimulation4Engine.transferNegotiationV2Engine.playerDecision(n.id, decision);
    } catch (_) {
      _toast('Ta oferta nie jest już dostępna.');
      return;
    }
    if (!ok) return;
    _emitDecisionEvent(category: 'transfer', decision: decision, clubId: n.buyerClubId);
    _refreshCareer();
    final text = decision == 'accept'
        ? 'Zaakceptowano warunki zawodnika.'
        : decision == 'negotiate'
            ? 'Agent wysłał kontrofertę.'
            : 'Oferta została odrzucona.';
    _toast(text);
  }

  void _contractDecision(ContractNegotiation n, String decision) {
    final engine2 = engine.worldEngine.worldSimulation4Engine.contractNegotiationEngine;
    bool ok = false;
    try {
      ok = decision == 'accept'
          ? engine2.acceptForPlayer(n.id, engine.players, engine.clubs)
          : decision == 'reject'
              ? engine2.rejectForPlayer(n.id, engine.players)
              : engine2.counterForPlayer(n.id);
    } catch (_) {
      _toast('Ta negocjacja nie jest już dostępna.');
      return;
    }
    if (!ok) return;
    _emitDecisionEvent(category: 'contract', decision: decision, clubId: n.clubId);
    _refreshCareer();
    _toast(decision == 'accept' ? 'Kontrakt zaakceptowany.' : decision == 'reject' ? 'Negocjacje kontraktu odrzucone.' : 'Wysłano kontrofertę kontraktową.');
  }

  void _sponsorDecision(bool accept) {
    final p = _worldPlayer;
    if (p == null) return;
    if (accept) {
      p.sponsorTier = p.sponsorTier.clamp(1, 3).toInt();
      p.sponsorIncome = p.sponsorIncome > 0 ? p.sponsorIncome : (p.marketability * 250).round();
      p.commercialEvents++;
      p.marketingValue = ((p.marketability * .65) + (p.fame * .35)).round().clamp(0, 100).toInt();
      engine.worldEngine.worldSimulation4Engine.recentEvents.add(engine.worldEngine.worldEventForPlayer(
        type: 'commercial_decision', title: 'Zawodnik przyjął współpracę sponsorską',
        description: '${p.name} wykorzystuje rosnącą popularność poza boiskiem.', playerId: p.id, importance: 2,
      ));
      _toast('Współpraca sponsorska zaakceptowana.');
    } else {
      p.sponsorInterest = (p.sponsorInterest - 10).clamp(0, 100).toInt();
      _toast('Odrzucono ofertę sponsorską.');
    }
    _emitDecisionEvent(category: 'sponsor', decision: accept ? 'accept' : 'reject', clubId: p.clubId);
    _refreshCareer();
  }

  void _interviewDecision(bool accept) {
    final p = _worldPlayer;
    if (p == null || p.interviewInvites <= 0) return;
    p.interviewInvites--;
    if (accept) {
      p.mediaAppearances++;
      p.mediaPressure = (p.mediaPressure + 5).clamp(0, 100).toInt();
      p.fame = (p.fame + (p.form >= 70 ? 2 : 1)).clamp(0, 100).toInt();
      p.reputation = (p.reputation + (p.form >= 70 ? 1 : 0)).clamp(0, 100).toInt();
      _toast('Wywiad przyjęty. Rozpoznawalność rośnie.');
    } else {
      p.mediaPressure = (p.mediaPressure - 2).clamp(0, 100).toInt();
      _toast('Odmówiono wywiadu. Presja medialna spada.');
    }
    _emitDecisionEvent(category: 'interview', decision: accept ? 'accept' : 'reject', clubId: p.clubId);
    _refreshCareer();
  }

  void _emitDecisionEvent({required String category, required String decision, String? clubId}) {
    final p = _worldPlayer;
    if (p == null) return;
    final club = clubId == null ? null : (engine.clubs.where((c) => c.id == clubId).isEmpty ? null : engine.clubs.where((c) => c.id == clubId).first);
    try {
      final event = engine.worldEngine.careerEventConsequencesEngine.decisionEvent(
        decision: decision, category: category, player: p, club: club,
        year: engine.state.year, month: engine.state.month, day: engine.state.day,
      );
      if (event != null) {
        engine.worldEngine.lastDayEvents.add(event);
        engine.worldEngine.worldEventHistory.add(event);
        engine.worldEngine.worldEventEngine.absorbExternalEvents([event]);
      }
      final storylineEvents = engine.worldEngine.careerStorylineEngine.decisionTrigger(
        category: category, decision: decision, player: p,
        absoluteDay: engine.worldEngine.absoluteDayForDate(engine.state.year, engine.state.month, engine.state.day),
        year: engine.state.year, month: engine.state.month, day: engine.state.day, club: club,
      );
      if (storylineEvents.isNotEmpty) {
        engine.worldEngine.lastDayEvents.addAll(storylineEvents);
        engine.worldEngine.worldEventHistory.addAll(storylineEvents);
        engine.worldEngine.worldEventEngine.absorbExternalEvents(storylineEvents);
      }
    } catch (_) {
      // A decision must never crash the whole hub. The decision itself is
      // already applied; downstream world effects may be retried on next tick.
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final career = _careerPlayer;
    final p = _worldPlayer;
    if (career == null || p == null) return Scaffold(body: Center(child: Text('Brak aktywnej kariery.')));

    final transfers = _transfers;
    final contracts = _contracts;
    final sponsorReady = p.sponsorInterest >= 78 && p.fame >= 70 && p.form >= 60;
    final interviewReady = p.interviewInvites > 0 && p.fame >= 50;
    final total = transfers.length + contracts.length + (sponsorReady ? 1 : 0) + (interviewReady ? 1 : 0);

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(title: Text('Centrum Decyzji'), actions: [IconButton(onPressed: _refreshCareer, icon: Icon(Icons.refresh))]),
      body: FadeTransition(
        opacity: _entrance,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            _hero(career, total),
            SizedBox(height: 18),
            if (total == 0) _empty(),
            _storylineShortcut(),
            ...transfers.map(_transferCard),
            ...contracts.map(_contractCard),
            if (sponsorReady) _sponsorCard(p),
            if (interviewReady) _interviewCard(p),
            SizedBox(height: 16),
            Container(decoration: FPGDecor.glowCard(), child: Padding(padding: EdgeInsets.all(16), child: Row(children: [Icon(Icons.hub_outlined, color: FPGTheme.accent), SizedBox(width: 12), Expanded(child: Text('Decyzje tutaj nie omijają świata gry. Każda odpowiedź zmienia istniejący system kariery i może wywołać kolejne wydarzenia, media lub negocjacje.', style: TextStyle(color: FPGTheme.textPrimary)))]))),
          ],
        ),
      ),
    );
  }

  Widget _hero(PlayerCareer p, int count) => Container(
    padding: EdgeInsets.all(20),
    decoration: FPGDecor.heroCard(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TWOJA KARIERA', style: TextStyle(color: FPGTheme.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)), SizedBox(height: 5), Text(p.fullName, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary)), SizedBox(height: 5), Text('OVR ${p.overall} • Fame ${p.fame} • Reputation ${p.reputation}', style: TextStyle(color: FPGTheme.muted))])), Container(width: 56, height: 56, decoration: BoxDecoration(color: count > 0 ? FPGTheme.accent : FPGTheme.surface2, borderRadius: BorderRadius.circular(18)), child: Center(child: Text('$count', style: TextStyle(color: count > 0 ? (FPGTheme.isLight ? Colors.white : Colors.black) : FPGTheme.textPrimary, fontSize: 23, fontWeight: FontWeight.w900))))]),
      SizedBox(height: 16),
      Row(children: [_mini('KIBICE', p.fanSupport), SizedBox(width: 8), _mini('MEDIA', p.mediaPressure), SizedBox(width: 8), _mini('MARKETING', p.marketingValue)]),
    ]),
  );


  Widget _storylineShortcut() => _decisionCard(Icons.auto_stories_outlined, 'STORYLINES', 'Historie kariery', 'Wielostopniowe historie i ich konsekwencje', [
    _button('OTWÓRZ', () async { await Navigator.push(context, FPGPageRoute(builder: (_) => CareerStorylinesScreen(engine: engine))); if (mounted) setState(() {}); }),
  ]);

  Widget _transferCard(TransferNegotiation n) => _decisionCard(Icons.swap_horiz, 'TRANSFER', 'Negocjacje transferowe', 'Runda ${n.round} • €${n.offeredFee} oferta / €${n.demandedFee} żądanie', [
    _button('ODRZUĆ', () => _transferDecision(n, 'reject'), secondary: true),
    _button('NEGOCJUJ', () => _transferDecision(n, 'negotiate')),
    _button('AKCEPTUJ', () => _transferDecision(n, 'accept')),
  ]);

  Widget _contractCard(ContractNegotiation n) => _decisionCard(Icons.description_outlined, 'KONTRAKT', 'Przedłużenie umowy', 'Runda ${n.round} • €${n.offeredWage}/tydz. → €${n.demandedWage}/tydz.', [
    _button('ODRZUĆ', () => _contractDecision(n, 'reject'), secondary: true),
    _button('KONTROFERTA', () => _contractDecision(n, 'counter')),
    _button('AKCEPTUJ', () => _contractDecision(n, 'accept')),
  ]);

  Widget _sponsorCard(Player p) => _decisionCard(Icons.handshake_outlined, 'SPONSOR', 'Oferta współpracy komercyjnej', 'Zainteresowanie ${p.sponsorInterest}% • marketing ${p.marketingValue}', [
    _button('ODRZUĆ', () => _sponsorDecision(false), secondary: true),
    _button('AKCEPTUJ', () => _sponsorDecision(true)),
  ]);

  Widget _interviewCard(Player p) => _decisionCard(Icons.mic_none, 'MEDIA', 'Zaproszenie na wywiad', '${p.interviewInvites} aktywne zaproszenie • presja ${p.mediaPressure}', [
    _button('ODMÓW', () => _interviewDecision(false), secondary: true),
    _button('PRZYJMIJ', () => _interviewDecision(true)),
  ]);

  Widget _decisionCard(IconData icon, String tag, String title, String sub, List<Widget> buttons) => Container(margin: EdgeInsets.only(bottom: 12), decoration: FPGDecor.glowCard(), child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: FPGTheme.accent), SizedBox(width: 10), Text(tag, style: TextStyle(color: FPGTheme.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1))]), SizedBox(height: 10), Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary)), SizedBox(height: 5), Text(sub, style: TextStyle(color: FPGTheme.muted)), SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: buttons)])));

  Widget _button(String text, VoidCallback onTap, {bool secondary = false}) => OutlinedButton(onPressed: () {
    HapticFeedback.selectionClick();
    unawaited(FPGAudio.playSfx(FPGAudio.click));
    onTap();
  }, style: OutlinedButton.styleFrom(backgroundColor: secondary ? Colors.transparent : FPGTheme.accent, foregroundColor: secondary ? FPGTheme.textPrimary : (FPGTheme.isLight ? Colors.white : Colors.black), side: BorderSide(color: secondary ? FPGTheme.cardBorder : FPGTheme.accent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(text, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)));

  Widget _mini(String label, int value) => Expanded(child: Container(padding: EdgeInsets.symmetric(vertical: 9), decoration: BoxDecoration(color: FPGTheme.surface2, borderRadius: BorderRadius.circular(12)), child: Column(children: [Text('$value', style: TextStyle(fontWeight: FontWeight.w900, color: FPGTheme.textPrimary)), Text(label, style: TextStyle(color: FPGTheme.muted, fontSize: 9))])));
  Widget _empty() => Container(decoration: FPGDecor.glowCard(), child: Padding(padding: EdgeInsets.all(28), child: Column(children: [Icon(Icons.check_circle_outline, size: 42, color: FPGTheme.accent), SizedBox(height: 12), Text('BRAK PILNYCH DECYZJI', style: TextStyle(fontWeight: FontWeight.w900, color: FPGTheme.textPrimary)), SizedBox(height: 6), Text('Świat działa w tle. Gdy pojawi się ważna oferta lub możliwość, trafi tutaj.', textAlign: TextAlign.center, style: TextStyle(color: FPGTheme.muted))])));
}
