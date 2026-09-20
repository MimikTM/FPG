import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/fpg_theme.dart';
import '../core/game_settings.dart';
import '../core/audio_service.dart';
import '../main.dart';
import '../widgets/fpg_animated.dart';

class TutorialScreen extends StatefulWidget {
  final bool manual;

  const TutorialScreen({super.key, this.manual = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _anim;

  static const List<_Step> steps = <_Step>[
    _Step(
      Icons.person_add_alt_1_rounded,
      'ZAWODNIK',
      'Stwórz zawodnika: wybierz pozycję, wiek, wzrost i początkowy OVR.',
    ),
    _Step(
      Icons.shield_outlined,
      'KLUB',
      'Wybierz klub. Poziom ligi wpływa na rywali, presję i rozwój.',
    ),
    _Step(
      Icons.badge_outlined,
      'PROFIL',
      'Śledź OVR, formę, kondycję, kontrakt, relacje i reputację.',
    ),
    _Step(
      Icons.fitness_center_rounded,
      'TRENING',
      'Trening rozwija statystyki. Minigry dają XP i dodatkowe efekty za dobre wykonanie.',
    ),
    _Step(
      Icons.sports_soccer_rounded,
      'MECZ',
      'Twoje decyzje, przygotowanie i minigry wpływają na ocenę oraz przebieg spotkania.',
    ),
    _Step(
      Icons.battery_charging_full_rounded,
      'REGENERACJA',
      'Zmęczenie ma znaczenie. Odpoczynek przygotowuje Cię do kolejnych spotkań.',
    ),
    _Step(
      Icons.handshake_outlined,
      'KONTRAKT',
      'Forma i wyniki wpływają na Twoją sytuację oraz możliwości negocjacyjne.',
    ),
    _Step(
      Icons.swap_horiz_rounded,
      'TRANSFERY',
      'Rynek reaguje na OVR, formę, reputację i sytuację klubów.',
    ),
    _Step(
      Icons.calendar_month_rounded,
      'KALENDARZ',
      'Świat działa dzień po dniu: mecze, treningi, wydarzenia, finanse i transfery.',
    ),
    _Step(
      Icons.save_outlined,
      'ZAPIS',
      'Autozapis i ręczny zapis chronią karierę. Save działa w prywatnej pamięci aplikacji.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    FPGAudio.playSfx(FPGAudio.success);
    await GameSettings.setTutorialCompleted(true);
    if (!mounted) return;

    if (widget.manual) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushReplacement(
        FPGPageRoute<void>(
          builder: (_) => FPGHomePage(),
        ),
      );
    }
  }

  Future<void> _next() async {
    HapticFeedback.selectionClick();
    FPGAudio.playSfx(FPGAudio.click);

    if (_step == steps.length - 1) {
      await _finish();
      return;
    }

    await _anim.reverse();
    if (!mounted) return;
    setState(() => _step++);
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final _Step item = steps[_step];

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: const Text('TUTORIAL'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('POMIŃ'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / steps.length,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_step + 1}/${steps.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: FPGTheme.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FadeTransition(
                  opacity: _anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(.04, 0),
                      end: Offset.zero,
                    ).animate(_anim),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    FPGTheme.accent.withValues(alpha: .25),
                                    FPGTheme.secondary.withValues(alpha: .16),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: FPGTheme.accent.withValues(alpha: .35),
                                ),
                              ),
                              child: Icon(
                                item.icon,
                                size: 48,
                                color: FPGTheme.accent,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item.text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.55,
                                color: FPGTheme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _next,
                  icon: Icon(
                    _step == steps.length - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(
                    _step == steps.length - 1
                        ? 'ROZPOCZNIJ KARIERĘ'
                        : 'DALEJ',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String text;

  const _Step(this.icon, this.title, this.text);
}
