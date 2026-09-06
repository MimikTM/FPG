import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';
import '../widgets/fpg_animated.dart';

class LifestyleScreen extends StatefulWidget {
  final GameEngine engine;

  LifestyleScreen({
    super.key,
    required this.engine,
  });

  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> with SingleTickerProviderStateMixin {
  int _relationshipStatus = 65; // Relacja z dziewczyną (0-100)
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

  void _triggerActivity(String type) {
    final player = widget.engine.careerPlayer;
    if (player == null) return;

    HapticFeedback.mediumImpact();
    unawaited(FPGAudio.playSfx(FPGAudio.success));

    String message = '';
    setState(() {
      switch (type) {
        case 'DATE':
          _relationshipStatus = (_relationshipStatus + 12).clamp(0, 100).toInt();
          player.morale = (player.morale + 8).clamp(0, 100).toInt();
          player.fatigue = (player.fatigue + 5).clamp(0, 100).toInt();
          message = 'Spędziłeś miły wieczór z partnerką. Morale +8, Zmęczenie +5.';
          break;

        case 'REST':
          player.fatigue = (player.fatigue - 20).clamp(0, 100).toInt();
          player.fitness = (player.fitness + 10).clamp(0, 100).toInt();
          message = 'Zostałeś w domu i odpocząłeś przed meczem. Zmęczenie -20.';
          break;

        case 'PARTY':
          _relationshipStatus = (_relationshipStatus - 10).clamp(0, 100).toInt();
          player.morale = (player.morale + 15).clamp(0, 100).toInt();
          player.fatigue = (player.fatigue + 25).clamp(0, 100).toInt();
          message = 'Impreza na mieście! Morale +15, ale Zmęczenie +25 i spadek relacji.';
          break;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: FPGTheme.surface2,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.engine.careerPlayer;

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: Text('Życie i Obozowisko'),
        backgroundColor: FPGTheme.bg,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrance,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              // KARTA RELACJI
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: FPGDecor.glowCard(accent: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite, color: Colors.pinkAccent, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Życie Osobiste & Partnerka',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: FPGTheme.textPrimary),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Jakość Relacji:', style: TextStyle(color: FPGTheme.muted)),
                        Row(
                          children: [
                            CountUpNumber(
                              value: _relationshipStatus,
                              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.pinkAccent, fontSize: 16),
                            ),
                            Text(' / 100', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.pinkAccent, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _relationshipStatus / 100.0),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: FPGTheme.surface2,
                          color: Colors.pinkAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              Text(
                'AKTYWNOŚCI POZA BOISKIEM',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.1, color: FPGTheme.textPrimary),
              ),
              SizedBox(height: 10),

              _activityTile(
                icon: Icons.restaurant,
                title: 'Wyjście na kolację z partnerką',
                subtitle: 'Podnosi relacje oraz morale, lekko zwiększa zmęczenie',
                onTap: () => _triggerActivity('DATE'),
              ),
              _activityTile(
                icon: Icons.hotel,
                title: 'Regeneracja w domu',
                subtitle: 'Znacząco obniża zmęczenie przed meczem',
                onTap: () => _triggerActivity('REST'),
              ),
              _activityTile(
                icon: Icons.nightlife,
                title: 'Wycisnąć noc na mieście z przyjaciółmi',
                subtitle: 'Ogromny skok morale, ale wysokie zmęczenie i spadek relacji',
                onTap: () => _triggerActivity('PARTY'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: FPGDecor.glowCard(),
      child: ListTile(
        leading: Icon(icon, color: Colors.pinkAccent),
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
