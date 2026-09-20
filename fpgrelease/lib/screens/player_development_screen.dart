import 'package:flutter/material.dart';
import '../core/game_engine.dart';
import '../core/training_engine.dart';
import '../core/fpg_theme.dart';
import '../models/player_career.dart';
import '../widgets/fpg_animated.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../core/audio_service.dart';

/// P2.2-C — development hub.
///
/// This screen is intentionally connected to the real GameEngine training
/// transaction. It does not mutate PlayerCareer directly, so the same daily
/// action rules used by Career Home are respected here as well.
class PlayerDevelopmentScreen extends StatefulWidget {
  final GameEngine engine;

  PlayerDevelopmentScreen({
    super.key,
    required this.engine,
  });

  @override
  State<PlayerDevelopmentScreen> createState() => _PlayerDevelopmentScreenState();
}

class _PlayerDevelopmentScreenState extends State<PlayerDevelopmentScreen> with SingleTickerProviderStateMixin {
  String? message;
  TrainingResult? lastResult;
  int? previousOverall;
  late final AnimationController _entrance;

  GameEngine get engine => widget.engine;

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

  void train(TrainingType type) {
    final player = engine.careerPlayer;
    if (player == null) return;

    final beforeOverall = player.overall;
    try {
      final result = engine.trainPlayer(type);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      unawaited(FPGAudio.playSfx(FPGAudio.success));
      setState(() {
        previousOverall = beforeOverall;
        lastResult = result;
        message = null;
      });
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      unawaited(FPGAudio.playSfx(FPGAudio.error));
      setState(() {
        message = e.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = engine.careerPlayer;

    if (player == null) {
      return Scaffold(
        backgroundColor: FPGTheme.bg,
        body: const Center(child: Text('Brak danych zawodnika.')),
      );
    }

    final gap = (player.potential - player.overall).clamp(0, 99);
    final potentialProgress = player.potential == 0 ? 0.0 : (player.overall / player.potential).clamp(0.0, 1.0);
    final canTrain = !engine.dailyCareerActionConsumed && !engine.careerHasMatchToday && player.fatigue < 90;

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: const Text('ROZWÓJ ZAWODNIKA'),
        backgroundColor: FPGTheme.bg,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrance,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
            _developmentHeader(player, gap, potentialProgress),
            const SizedBox(height: 14),
            _statusCard(player),
            if (lastResult != null) ...[
              const SizedBox(height: 12),
              _resultCard(player),
            ],
            if (message != null) ...[
              const SizedBox(height: 12),
              NeonGlowCard(
                glowColor: const Color(0xFFFF6B6B),
                child: Text(message!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
            const SizedBox(height: 26),
            const Text('PROFIL ZAWODNIKA', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: .3)),
            const SizedBox(height: 8),
            NeonGlowCard(
              glowColor: FPGTheme.accent,
              padding: const EdgeInsets.all(10),
              child: Center(
                child: AttributeRadar(
                  size: 250,
                  axes: [
                    RadarAxis('PAC', player.pace, const Color(0xFF67D9FF)),
                    RadarAxis('SHO', player.shooting, const Color(0xFFFF6B6B)),
                    RadarAxis('PAS', player.passing, const Color(0xFF43FFAF)),
                    RadarAxis('DRI', player.dribbling, const Color(0xFFA96BFF)),
                    RadarAxis('DEF', player.defending, const Color(0xFFFFC24B)),
                    RadarAxis('PHY', player.physical, const Color(0xFFFF9F5A)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedStatBar(label: 'TEMPO', value: player.pace, color: const Color(0xFF67D9FF)),
            AnimatedStatBar(label: 'STRZAŁY', value: player.shooting, color: const Color(0xFFFF6B6B)),
            AnimatedStatBar(label: 'PODANIA', value: player.passing, color: const Color(0xFF43FFAF)),
            AnimatedStatBar(label: 'DRYBLING', value: player.dribbling, color: const Color(0xFFA96BFF)),
            AnimatedStatBar(label: 'OBRONA', value: player.defending, color: const Color(0xFFFFC24B)),
            AnimatedStatBar(label: 'FIZYCZNY', value: player.physical, color: const Color(0xFFFF9F5A)),
            const SizedBox(height: 26),
            const Text('TRENING DZIŚ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: .3)),
            const SizedBox(height: 6),
            Text(
              canTrain
                  ? 'Wybierz jeden trening. To zużyje dzisiejszą akcję kariery.'
                  : engine.careerHasMatchToday
                      ? 'Dzisiaj masz mecz — trening jest niedostępny.'
                      : engine.dailyCareerActionConsumed
                          ? 'Dzisiejsza akcja została już wykorzystana.'
                          : 'Regeneruj się przed kolejnym ciężkim treningiem.',
              style: TextStyle(color: FPGTheme.muted),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _quickTrainCard('TEMPO', Icons.bolt_rounded, const Color(0xFF67D9FF), TrainingType.pace, canTrain),
                _quickTrainCard('STRZAŁY', Icons.sports_soccer_rounded, const Color(0xFFFF6B6B), TrainingType.shooting, canTrain),
                _quickTrainCard('PODANIA', Icons.share_rounded, const Color(0xFF43FFAF), TrainingType.passing, canTrain),
                _quickTrainCard('DRYBLING', Icons.change_history_rounded, const Color(0xFFA96BFF), TrainingType.dribbling, canTrain),
                _quickTrainCard('OBRONA', Icons.shield_rounded, const Color(0xFFFFC24B), TrainingType.defending, canTrain),
                _quickTrainCard('FIZYCZNY', Icons.fitness_center_rounded, const Color(0xFFFF9F5A), TrainingType.physical, canTrain),
                _quickTrainCard('BALANS', Icons.blur_circular_rounded, FPGTheme.secondary, TrainingType.balanced, canTrain),
              ],
            ),
            const SizedBox(height: 26),
            const Text('PERKI KARIERY', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: .3)),
            const SizedBox(height: 10),
            PerkTile(
              title: '🔥 Snajper',
              subtitle: '+5% do celności wykończenia',
              unlocked: player.overall >= 70,
              condition: 'OVR 70+',
              color: const Color(0xFFFF6B6B),
            ),
            PerkTile(
              title: '⚡ Sprinter',
              subtitle: 'Mniejsze zmęczenie kontratakiem',
              unlocked: player.pace >= 75,
              condition: 'PAC 75+',
              color: const Color(0xFF67D9FF),
            ),
            PerkTile(
              title: '🧊 Clutch Player',
              subtitle: 'Bonus w końcówkach spotkań',
              unlocked: player.overall >= 80,
              condition: 'OVR 80+',
            ),
            PerkTile(
              title: '🧠 Lider Szatni',
              subtitle: 'Wpływ na morale zespołu',
              unlocked: player.overall >= 85,
              condition: 'OVR 85+',
              color: FPGTheme.secondary,
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _developmentHeader(PlayerCareer player, int gap, double progress) {
    final ovrDelta = previousOverall == null ? 0 : player.overall - previousOverall!;
    return NeonGlowCard(
      glowColor: FPGTheme.accent,
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: FPGTheme.heroGradient),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OvrRing(value: player.overall, color: FPGTheme.accent),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _miniStat('POTENCJAŁ', player.potential, FPGTheme.secondary),
                        const SizedBox(width: 18),
                        _miniStat('WIEK', player.age, FPGTheme.textPrimary),
                      ],
                    ),
                    if (ovrDelta != 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        ovrDelta > 0 ? '↑ OVR +$ovrDelta po ostatnim treningu' : 'OVR $ovrDelta',
                        style: TextStyle(
                          color: ovrDelta > 0 ? const Color(0xFF43FFAF) : const Color(0xFFFF9F5A),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DROGA DO POTENCJAŁU', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              Text('$gap OVR do celu', style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              color: FPGTheme.surface2,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [FPGTheme.accent.withValues(alpha: .6), FPGTheme.secondary]),
                      boxShadow: [BoxShadow(color: FPGTheme.accent.withValues(alpha: .5), blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w700)),
          CountUpNumber(value: value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
        ],
      );

  Widget _statusCard(PlayerCareer player) {
    return NeonGlowCard(
      glowColor: FPGTheme.secondary,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        children: [
          Expanded(child: _smallStatus('FORMA', player.form, const Color(0xFF43FFAF))),
          Expanded(child: _smallStatus('FITNESS', player.fitness, const Color(0xFF67D9FF))),
          Expanded(child: _smallStatus('ZMĘCZENIE', player.fatigue, const Color(0xFFFF9F5A))),
          Expanded(child: _smallStatus('TRENER', player.managerRelationship, FPGTheme.secondary)),
        ],
      ),
    );
  }

  Widget _resultCard(PlayerCareer player) {
    final result = lastResult!;
    final before = previousOverall ?? player.overall;
    return NeonGlowCard(
      glowColor: const Color(0xFF43FFAF),
      intense: true,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, color: Color(0xFF43FFAF)),
          const SizedBox(width: 12),
          Expanded(child: Text('${result.name} • OVR $before → ${player.overall}', style: const TextStyle(fontWeight: FontWeight.w700))),
          CountUpNumber(value: result.primaryGain, prefix: '+', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF43FFAF), fontSize: 17)),
        ],
      ),
    );
  }

  Widget _smallStatus(String label, int value, Color color) => Column(
        children: [
          CountUpNumber(value: value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 9, color: FPGTheme.muted, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _quickTrainCard(String title, IconData icon, Color color, TrainingType type, bool enabled) {
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? () => train(type) : null,
        child: NeonGlowCard(
          glowColor: color,
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}
