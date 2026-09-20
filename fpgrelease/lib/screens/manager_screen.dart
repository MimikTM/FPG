import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';
import '../widgets/fpg_animated.dart';

class ManagerScreen extends StatefulWidget {
  final GameEngine engine;

  ManagerScreen({
    super.key,
    required this.engine,
  });

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _interactWithManager(String actionType) async {
    final player = widget.engine.careerPlayer;
    if (player == null || player.contract == null) return;
    final matches = widget.engine.players.where((p) => p.id == player.id).toList();
    if (matches.isEmpty) return;
    final world = matches.first;
    final web = widget.engine.worldEngine.relationshipWebEngine;
    final absolute = widget.engine.currentAbsoluteDay;
    String message;
    String decision;
    switch (actionType) {
      case 'MORE_MINUTES':
        decision = 'demand_role';
        message = 'Rozmowa o większej liczbie minut została zapisana.';
        break;
      case 'PRAISE_TACTICS':
        decision = 'reconcile';
        message = 'Trener docenił rozmowę. Zaufanie i relacja zostały zaktualizowane.';
        break;
      case 'TEAM_SUPPORT':
        decision = 'commit_club';
        message = 'Zadeklarowałeś wsparcie dla drużyny. Relacja z klubem rośnie.';
        break;
      case 'REQUEST_TRANSFER':
        decision = 'request_transfer';
        message = 'Poprosiłeś o transfer. Klub i trener reagują na tę decyzję.';
        break;
      default:
        return;
    }
    HapticFeedback.mediumImpact();
    unawaited(FPGAudio.playSfx(FPGAudio.success));
    web.applyDecision(
      p: world,
      decision: decision,
      absoluteDay: absolute,
      year: widget.engine.state.year,
      month: widget.engine.state.month,
      day: widget.engine.state.day,
    );
    // Synchronizacja obu modeli jest kluczowa: ekran relacji i kontrakt muszą
    // pokazywać tę samą wartość po wyjściu i ponownym wejściu.
    player.managerRelationship = web.forPlayer(world).coach;
    player.teamRelationship = web.forPlayer(world).club;
    player.contract!.managerTrust = player.managerRelationship;
    widget.engine.careerWorldBridge.pushCareerState(player);
    await widget.engine.saveWorld();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.engine.careerPlayer;

    if (player == null || player.contract == null) {
      return Scaffold(
        backgroundColor: FPGTheme.bg,
        body: Center(child: Text('Brak aktywnych danych kariery.', style: TextStyle(color: FPGTheme.muted))),
      );
    }

    final contract = player.contract!;
    final trustColor = contract.managerTrust >= 70
        ? Colors.greenAccent
        : (contract.managerTrust >= 40 ? Colors.orangeAccent : Colors.redAccent);

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: Text('Gabinet Trenera'),
        backgroundColor: FPGTheme.bg,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrance,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              // STATUS ZAUFANIA
              Container(
                padding: EdgeInsets.all(18),
                decoration: FPGDecor.glowCard(accent: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [FPGTheme.accent, FPGTheme.secondary]), shape: BoxShape.circle),
                          child: Icon(Icons.person, size: 30, color: FPGTheme.isLight ? Colors.white : Colors.black),
                        ),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Główny Szkoleniowiec',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary),
                            ),
                            Text(
                              'Status w składzie: ${contract.squadStatus}',
                              style: TextStyle(color: FPGTheme.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Poziom Zaufania:', style: TextStyle(color: FPGTheme.muted)),
                        Row(
                          children: [
                            CountUpNumber(
                              value: contract.managerTrust,
                              style: TextStyle(fontWeight: FontWeight.w900, color: trustColor, fontSize: 16),
                            ),
                            Text(' / 100', style: TextStyle(fontWeight: FontWeight.w900, color: trustColor, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: contract.managerTrust / 100.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: FPGTheme.surface2,
                          color: trustColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              Text(
                'ROZMOWA Z TRENEREM',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: FPGTheme.textPrimary),
              ),
              SizedBox(height: 10),

              _actionTile(
                icon: Icons.sports_soccer,
                title: 'Poproś o więcej minut na boisku',
                subtitle: 'Wymaga zaufania min. 60+',
                onTap: () => _interactWithManager('MORE_MINUTES'),
              ),
              _actionTile(
                icon: Icons.thumb_up,
                title: 'Pochwal taktykę przed meczem',
                subtitle: 'Zwiększa relację z trenerem (+4 trust)',
                onTap: () => _interactWithManager('PRAISE_TACTICS'),
              ),
              _actionTile(
                icon: Icons.groups_rounded,
                title: 'Wesprzyj drużynę i szatnię',
                subtitle: 'Buduje relację z zespołem i klubem',
                onTap: () => _interactWithManager('TEAM_SUPPORT'),
              ),
              _actionTile(
                icon: Icons.exit_to_app,
                title: 'Poproś o wpisanie na listę transferową',
                subtitle: 'Znacząco obniża relacje z trenerem (-15 trust)',
                onTap: () => _interactWithManager('REQUEST_TRANSFER'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: FPGDecor.glowCard(),
      child: ListTile(
        leading: Icon(icon, color: Colors.greenAccent),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: FPGTheme.textPrimary)),
        subtitle: Text(subtitle, style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: FPGTheme.muted),
        onTap: () {
          HapticFeedback.selectionClick();
          unawaited(FPGAudio.playSfx(FPGAudio.click));
          onTap();
        },
      ),
    );
  }
}
