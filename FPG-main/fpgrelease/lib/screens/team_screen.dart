import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';
import '../widgets/fpg_animated.dart';

class TeamScreen extends StatefulWidget {
  final GameEngine engine;

  TeamScreen({
    super.key,
    required this.engine,
  });

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> with SingleTickerProviderStateMixin {
  int _lockerRoomChemistry = 72; // Zgranie w szatni (0-100)
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

  void _teamBuilding(String action) {
    final player = widget.engine.careerPlayer;
    if (player == null) return;

    HapticFeedback.mediumImpact();
    unawaited(FPGAudio.playSfx(FPGAudio.success));

    String msg = '';
    setState(() {
      if (action == 'BBQ') {
        _lockerRoomChemistry = (_lockerRoomChemistry + 8).clamp(0, 100).toInt();
        player.morale = (player.morale + 5).clamp(0, 100).toInt();
        player.fatigue = (player.fatigue + 4).clamp(0, 100).toInt();
        msg = 'Zorganizowałeś wspólnego grilla dla drużyny! Zgranie +8, Morale +5.';
      } else if (action == 'TALK') {
        _lockerRoomChemistry = (_lockerRoomChemistry + 4).clamp(0, 100).toInt();
        msg = 'Motywacyjna mowa w szatni przed meczem podniosła duch zespołu! (+4 Zgrania)';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: FPGTheme.surface2,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.engine.careerPlayer;
    final clubName = widget.engine.clubs
        .firstWhere((c) => c.id == player?.clubId, orElse: () => widget.engine.clubs.first)
        .name;

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: Text('Relacje z Drużyną'),
        backgroundColor: FPGTheme.bg,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrance,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              // KARTA ZGRANIA SZATNI
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: FPGDecor.glowCard(accent: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Szatnia: $clubName',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary),
                    ),
                    SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Zgranie i Atmosfera:', style: TextStyle(color: FPGTheme.muted)),
                        Row(
                          children: [
                            CountUpNumber(
                              value: _lockerRoomChemistry,
                              style: TextStyle(fontWeight: FontWeight.w900, color: FPGTheme.accent, fontSize: 16),
                            ),
                            Text(' / 100', style: TextStyle(fontWeight: FontWeight.w900, color: FPGTheme.accent, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _lockerRoomChemistry / 100.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: FPGTheme.surface2,
                          color: FPGTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              Text(
                'INTEGRACJA Z DRUŻYNĄ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: FPGTheme.textPrimary),
              ),
              SizedBox(height: 10),

              _teamTile(
                icon: Icons.sports_bar,
                title: 'Wspólny grill / wyjście integracyjne',
                subtitle: 'Podnosi zgranie szatni i morale zespołu (+8 Zgrania)',
                onTap: () => _teamBuilding('BBQ'),
              ),
              _teamTile(
                icon: Icons.campaign,
                title: 'Mowa motywacyjna w szatni',
                subtitle: 'Buduje Twoją pozycję jako lidera zespołu (+4 Zgrania)',
                onTap: () => _teamBuilding('TALK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: FPGDecor.glowCard(),
      child: ListTile(
        leading: Icon(icon, color: FPGTheme.accent),
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
