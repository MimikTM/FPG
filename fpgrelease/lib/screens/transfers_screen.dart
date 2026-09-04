import 'package:flutter/material.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../models/club.dart';
import '../models/transfer_negotiation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../core/audio_service.dart';
import '../widgets/fpg_animated.dart';

/// V18.9 — Transfer Market UI & Player Decisions.
///
/// Ekran nie generuje już fikcyjnych ofert. Pokazuje negocjacje pochodzące
/// z tego samego World Simulation, w którym działają kluby AI.
class TransfersScreen extends StatefulWidget {
  final GameEngine engine;
  TransfersScreen({super.key, required this.engine});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> with SingleTickerProviderStateMixin {
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

  List<TransferNegotiation> get _negotiations {
    final player = engine.careerPlayer;
    if (player == null) return [];
    return engine.worldEngine.worldSimulation4Engine.transferNegotiationV2Engine
        .activeForPlayer(player.id);
  }

  Club? _club(String id) => engine.clubs.where((c) => c.id == id).firstOrNull;

  void _requestTransfer(dynamic player) {
    if (!engine.summerTransferWindow && !engine.winterTransferWindow) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfery są obecnie zamknięte.')));
      return;
    }
    final world = engine.worldEngine.worldSimulation4Engine;
    final created = world.transferInterestEngine.requestTransfer(
      clubs: engine.clubs,
      player: engine.careerPlayer!,
      absoluteDay: engine.currentAbsoluteDay,
      agentEngine: world.agentEngine,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(created.isEmpty ? 'Nie znaleziono odpowiednich klubów.' : 'Agent rozpoczął rozmowy z ${created.length} klubami.')),
    );
  }

  void _decision(TransferNegotiation n, String decision) {
    final ok = engine.worldEngine.worldSimulation4Engine.transferNegotiationV2Engine
        .playerDecision(n.id, decision);
    if (!ok) return;
    HapticFeedback.mediumImpact();
    unawaited(FPGAudio.playSfx(decision == 'accept' ? FPGAudio.success : FPGAudio.click));
    setState(() {});
    final label = decision == 'accept'
        ? 'Akceptowałeś warunki zawodnika.'
        : decision == 'negotiate'
            ? 'Wysłano kontrofertę agenta.'
            : 'Odrzuciłeś ofertę.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  @override
  Widget build(BuildContext context) {
    final player = engine.careerPlayer;
    final negotiations = _negotiations;
    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: Text('Rynek Transferowy'),
        backgroundColor: FPGTheme.bg,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {});
          }),
        ],
      ),
      body: player == null
          ? Center(child: Text('Brak aktywnej kariery.'))
          : FadeTransition(
              opacity: _entrance,
              child: ListView(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                _playerHeader(player),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _requestTransfer(player),
                    icon: Icon(Icons.campaign_outlined),
                    label: Text('POPROŚ O TRANSFER'),
                  ),
                ),
                SizedBox(height: 18),
                Text('AKTYWNE NEGOCJACJE', style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: FPGTheme.muted)),
                SizedBox(height: 10),
                if (negotiations.isEmpty) _empty(),
                ...negotiations.map(_negotiationCard),
                SizedBox(height: 14),
                Container(
                  decoration: FPGDecor.glowCard(),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: FPGTheme.accent),
                      SizedBox(width: 12),
                      Expanded(child: Text('Akceptacja oznacza zgodę zawodnika na warunki. Transfer dojdzie do skutku dopiero, gdy klub kupujący i sprzedający domkną swoje warunki.')),
                    ]),
                  ),
                ),
              ],
            ),
            ),
    );
  }

  Widget _playerHeader(dynamic player) => Container(
        decoration: FPGDecor.glowCard(accent: true),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(player.fullName, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('OVR ${player.overall} • Fame ${player.fame} • Reputation ${player.reputation}', style: TextStyle(color: FPGTheme.muted)),
              ])),
              Text('${((player.contract?.marketValue ?? 0) / 1000000).toStringAsFixed(1)} mln €', style: TextStyle(color: FPGTheme.accent, fontWeight: FontWeight.w900)),
            ]),
            SizedBox(height: 14),
            Row(children: [
              Expanded(child: _metric('PENSJA', '${player.contract?.weeklySalary.toStringAsFixed(0) ?? 0} €')),
              SizedBox(width: 8),
              Expanded(child: _metric('MARKETING', '${player.marketability}')),
              SizedBox(width: 8),
              Expanded(child: _metric('AGENT', '${player.agentInfluence}')),
            ]),
          ]),
        ),
      );

  Widget _negotiationCard(TransferNegotiation n) {
    final buyer = _club(n.buyerClubId);
    final seller = _club(n.sellerClubId);
    final decision = n.playerDecision;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: FPGDecor.glowCard(),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(buyer?.name ?? n.buyerClubId, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
            _stageChip(n.stage),
          ]),
          SizedBox(height: 5),
          Text('Sprzedający: ${seller?.name ?? n.sellerClubId} • Runda ${n.round}/7', style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
          SizedBox(height: 16),
          _dealRow('Kwota transferu', '${n.offeredFee} €', '${n.demandedFee} €'),
          _dealRow('Pensja / tydz.', '${n.offeredWage} €', '${n.demandedWage} €'),
          _dealRow('Bonus podpisowy', '${n.offeredSigningBonus} €', '${n.demandedSigningBonus} €'),
          _dealRow('Długość', '${n.offeredYears} lata', '${n.demandedYears} lata'),
          _dealRow('Rola', '${n.offeredRoleScore}', '${n.demandedRoleScore}'),
          SizedBox(height: 14),
          if (decision != 'pending') _decisionStatus(decision),
          SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _decision(n, 'reject'), child: Text('ODRZUĆ'))),
            SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _decision(n, 'negotiate'), child: Text('NEGOCJUJ'))),
            SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: () => _decision(n, 'accept'), child: Text('AKCEPTUJ'))),
          ]),
        ]),
      ),
    );
  }

  Widget _dealRow(String label, String offer, String demand) => Padding(
        padding: EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: FPGTheme.muted))),
          Text(offer, style: TextStyle(color: FPGTheme.muted)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 7), child: Icon(Icons.arrow_forward, size: 13, color: FPGTheme.muted)),
          Text(demand, style: TextStyle(fontWeight: FontWeight.w800, color: FPGTheme.accent)),
        ]),
      );

  Widget _decisionStatus(String decision) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: FPGTheme.surface2, borderRadius: BorderRadius.circular(10)),
        child: Text(
          decision == 'accepted' ? '✓ ZAWODNIK ZAAKCEPTOWAŁ WARUNKI' : decision == 'negotiating' ? '↔ AGENT NEGOCJUJE' : '✕ OFERTA ODRZUCONA',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      );

  Widget _stageChip(String stage) => Container(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: FPGTheme.accent.withValues(alpha:  .12), borderRadius: BorderRadius.circular(8)),
        child: Text(stage.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: FPGTheme.accent, fontSize: 9, fontWeight: FontWeight.w900)),
      );

  Widget _metric(String label, String value) => Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(color: FPGTheme.surface2, borderRadius: BorderRadius.circular(11)),
        child: Column(children: [Text(value, style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 3), Text(label, style: TextStyle(fontSize: 9, color: FPGTheme.muted))]),
      );

  Widget _empty() => Container(decoration: FPGDecor.glowCard(), child: Padding(padding: EdgeInsets.all(26), child: Column(children: [
    Icon(Icons.mark_email_unread_outlined, size: 42, color: FPGTheme.muted),
    SizedBox(height: 10),
    Text('Brak aktywnych negocjacji', style: TextStyle(fontWeight: FontWeight.w800)),
    SizedBox(height: 6),
    Text('Zainteresowanie klubów pojawi się, gdy Twoja forma, Fame i sytuacja kontraktowa zaczną przyciągać rynek.', textAlign: TextAlign.center, style: TextStyle(color: FPGTheme.muted)),
  ])));
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
