import 'package:flutter/material.dart';

import '../core/game_engine.dart';
import '../core/training_engine.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';
import '../models/player_career.dart';
import '../widgets/fpg_animated.dart';

class TrainingScreen extends StatefulWidget {
  final GameEngine engine;

  TrainingScreen({
    super.key,
    required this.engine,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

enum _Phase { menu, minigame, result }

class _TrainingTypeMeta {
  final String title;
  final String subtitle;
  final TrainingType type;
  final IconData icon;
  final Color color;
  const _TrainingTypeMeta(this.title, this.subtitle, this.type, this.icon, this.color);
}

const _kTrainingTypes = [
  _TrainingTypeMeta('TEMPO', 'Rozwój szybkości', TrainingType.pace, Icons.bolt_rounded, Color(0xFF67D9FF)),
  _TrainingTypeMeta('STRZAŁY', 'Rozwój wykończenia', TrainingType.shooting, Icons.sports_soccer_rounded, Color(0xFFFF6B6B)),
  _TrainingTypeMeta('PODANIA', 'Rozwój podań', TrainingType.passing, Icons.share_rounded, Color(0xFF43FFAF)),
  _TrainingTypeMeta('DRYBLING', 'Rozwój dryblingu', TrainingType.dribbling, Icons.change_history_rounded, Color(0xFFA96BFF)),
  _TrainingTypeMeta('OBRONA', 'Rozwój defensywy', TrainingType.defending, Icons.shield_rounded, Color(0xFFFFC24B)),
  _TrainingTypeMeta('FIZYCZNY', 'Siła i wytrzymałość', TrainingType.physical, Icons.fitness_center_rounded, Color(0xFFFF9F5A)),
];

class _TrainingScreenState extends State<TrainingScreen> {
  _Phase phase = _Phase.menu;
  _TrainingTypeMeta? selected;
  PrecisionResult? precision;
  TrainingResult? result;
  String? error;

  bool get _usedToday => widget.engine.dailyCareerActionConsumed;

  void _pick(_TrainingTypeMeta meta) {
    FPGAudio.playSfx(FPGAudio.click);
    setState(() {
      selected = meta;
      precision = null;
      error = null;
      phase = _Phase.minigame;
    });
  }

  void _onPrecisionLocked(PrecisionResult r) {
    setState(() => precision = r);
    Future.delayed(const Duration(milliseconds: 550), _commitTraining);
  }

  void _commitTraining() {
    if (selected == null) return;
    try {
      final res = widget.engine.trainPlayer(selected!.type);
      FPGAudio.playSfx(FPGAudio.success);
      setState(() {
        result = res;
        error = null;
        phase = _Phase.result;
      });
    } catch (e) {
      FPGAudio.playSfx(FPGAudio.error);
      setState(() {
        error = e.toString().replaceFirst('Bad state: ', '');
        phase = _Phase.result;
      });
    }
  }

  void _backToMenu() {
    setState(() {
      phase = _Phase.menu;
      selected = null;
      precision = null;
      result = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.engine.careerPlayer;

    if (player == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('TRENING')),
        body: const Center(child: Text('Najpierw utwórz zawodnika.')),
      );
    }

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: const Text('TRENING'),
        backgroundColor: FPGTheme.bg,
        leading: phase == _Phase.menu
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _usedToday && phase == _Phase.result ? () => Navigator.of(context).maybePop() : _backToMenu,
              ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: switch (phase) {
            _Phase.menu => _MenuView(key: const ValueKey('menu'), engine: widget.engine, player: player, usedToday: _usedToday, onPick: _pick),
            _Phase.minigame => _MiniGameView(key: const ValueKey('minigame'), meta: selected!, onLocked: _onPrecisionLocked),
            _Phase.result => _ResultView(
                key: const ValueKey('result'),
                meta: selected!,
                precision: precision,
                result: result,
                error: error,
                onDone: _backToMenu,
              ),
          },
        ),
      ),
    );
  }
}

// ================================================================
// MENU
// ================================================================

class _MenuView extends StatelessWidget {
  final GameEngine engine;
  final PlayerCareer player;
  final bool usedToday;
  final ValueChanged<_TrainingTypeMeta> onPick;

  const _MenuView({super.key, required this.engine, required this.player, required this.usedToday, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        NeonGlowCard(
          glowColor: FPGTheme.accent,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: FPGTheme.heroGradient),
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OvrRing(value: player.overall, color: FPGTheme.accent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.fullName,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    AnimatedStatBar(label: 'FORMA', value: player.form, color: const Color(0xFF43FFAF)),
                    AnimatedStatBar(label: 'KONDYCJA', value: player.fitness, color: const Color(0xFF67D9FF)),
                    AnimatedStatBar(label: 'ZMĘCZENIE', value: player.fatigue, color: const Color(0xFFFF9F5A)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        NeonGlowCard(
          glowColor: usedToday ? const Color(0xFF43FFAF) : FPGTheme.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _PulsingIcon(
                icon: usedToday ? Icons.check_circle_rounded : Icons.bolt_rounded,
                color: usedToday ? const Color(0xFF43FFAF) : Colors.lightBlueAccent,
                pulse: !usedToday,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  usedToday ? 'AKCJA DNIA: TRENING WYKONANY' : 'AKCJA DNIA: TRENING DOSTĘPNY',
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text('WYBIERZ TRENING', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: .3)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: _kTrainingTypes.map((m) => _TrainingCard(meta: m, disabled: usedToday, onTap: () => onPick(m))).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PulsingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool pulse;
  const _PulsingIcon({required this.icon, required this.color, required this.pulse});

  @override
  Widget build(BuildContext context) => PulsingIcon(icon: icon, color: color, pulse: pulse);
}

class _TrainingCard extends StatelessWidget {
  final _TrainingTypeMeta meta;
  final bool disabled;
  final VoidCallback onTap;
  const _TrainingCard({required this.meta, required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? .45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: disabled ? null : onTap,
        child: NeonGlowCard(
          glowColor: meta.color,
          radius: 20,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: meta.color.withValues(alpha: .16), shape: BoxShape.circle),
                child: Icon(meta.icon, color: meta.color, size: 22),
              ),
              const Spacer(),
              Text(meta.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: .3)),
              const SizedBox(height: 2),
              Text(meta.subtitle, style: TextStyle(fontSize: 11, color: FPGTheme.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// MINI-GAME
// ================================================================

class _MiniGameView extends StatelessWidget {
  final _TrainingTypeMeta meta;
  final ValueChanged<PrecisionResult> onLocked;
  const _MiniGameView({super.key, required this.meta, required this.onLocked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: meta.color.withValues(alpha: .16), shape: BoxShape.circle),
            child: Icon(meta.icon, color: meta.color, size: 40),
          ),
          const SizedBox(height: 18),
          Text(meta.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: .4)),
          const SizedBox(height: 6),
          Text(
            'Stuknij, gdy suwak trafi w zielone pole na środku',
            textAlign: TextAlign.center,
            style: TextStyle(color: FPGTheme.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 34),
          PrecisionBar(accent: meta.color, onLocked: onLocked),
          const SizedBox(height: 14),
          Text('STUKNIJ EKRAN, ABY ZATRZYMAĆ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: FPGTheme.muted)),
        ],
      ),
    );
  }
}

// ================================================================
// RESULT
// ================================================================

class _ResultView extends StatelessWidget {
  final _TrainingTypeMeta meta;
  final PrecisionResult? precision;
  final TrainingResult? result;
  final String? error;
  final VoidCallback onDone;

  const _ResultView({
    super.key,
    required this.meta,
    required this.precision,
    required this.result,
    required this.error,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 48),
            const SizedBox(height: 14),
            Text(error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onDone, child: const Text('WRÓĆ')),
          ],
        ),
      );
    }

    final r = result!;
    final zone = precision?.zone ?? PrecisionZone.ok;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (zone == PrecisionZone.perfect) SparkleBurst(color: zone.color, size: 140),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: zone.color.withValues(alpha: .16),
                  boxShadow: [BoxShadow(color: zone.color.withValues(alpha: .4), blurRadius: 26, spreadRadius: 2)],
                ),
                child: Icon(Icons.check_rounded, color: zone.color, size: 46),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(zone.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: zone.color, letterSpacing: .5)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text('TRENING: ${r.name}', style: TextStyle(color: FPGTheme.muted, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 22),
        NeonGlowCard(
          glowColor: meta.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _GainStat(label: 'GŁÓWNY ROZWÓJ', value: r.primaryGain, color: meta.color),
                  _GainStat(label: 'DODATKOWY', value: r.secondaryGain, color: FPGTheme.secondary),
                  _GainStat(label: 'ZMĘCZENIE', value: r.fatigue, color: const Color(0xFFFF9F5A), prefix: '+'),
                ],
              ),
              const Divider(height: 28),
              Text(r.description, style: TextStyle(color: FPGTheme.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Dzisiejsza akcja kariery została wykorzystana. Następny trening będzie dostępny po przejściu dnia.',
                style: TextStyle(color: FPGTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onDone, child: const Text('ZAKOŃCZ')),
      ],
    );
  }
}

class _GainStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String prefix;
  const _GainStat({required this.label, required this.value, required this.color, this.prefix = '+'});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CountUpNumber(
          value: value,
          prefix: prefix,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: FPGTheme.muted), textAlign: TextAlign.center),
      ],
    );
  }
}
