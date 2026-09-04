import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_engine.dart';
import '../models/player.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';

class CreatePlayerScreen extends StatefulWidget {
  final GameEngine engine;

  CreatePlayerScreen({super.key, required this.engine});

  @override
  State<CreatePlayerScreen> createState() => _CreatePlayerScreenState();
}

class _CreatePlayerScreenState extends State<CreatePlayerScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final nationalityController = TextEditingController(text: 'Polska');
  final heightController = TextEditingController(text: '178');
  final ageController = TextEditingController(text: '18');

  PlayerPosition selectedPosition = PlayerPosition.winger;
  int startingOverall = 60;
  bool _creating = false;

  late final AnimationController _entrance;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    nationalityController.dispose();
    heightController.dispose();
    ageController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  // ==========================================================
  // UTWORZENIE ZAWODNIKA
  // ==========================================================

  Future<void> createPlayer() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      unawaited(FPGAudio.playSfx(FPGAudio.error));
      return;
    }

    final age = int.parse(ageController.text);
    final height = int.parse(heightController.text);

    setState(() => _creating = true);

    widget.engine.createPlayer(
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      nationality: nationalityController.text.trim(),
      age: age,
      height: height,
      position: selectedPosition,
      // Bazowe statystyki odpowiadają wybranemu OVR.
      pace: startingOverall,
      shooting: startingOverall,
      passing: startingOverall,
      dribbling: startingOverall,
      defending: startingOverall,
      physical: startingOverall,
      initialOverall: startingOverall,
    );

    final saved = await widget.engine.saveWorld();
    if (!mounted) return;
    if (!saved) {
      // Creation is transactional from the player's perspective: do not
      // leave the user in a career that was never persisted.
      widget.engine.careerPlayer = null;
      setState(() => _creating = false);
      HapticFeedback.heavyImpact();
      unawaited(FPGAudio.playSfx(FPGAudio.error));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się zapisać kariery. Spróbuj ponownie.')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    unawaited(FPGAudio.playSfx(FPGAudio.success));
    Navigator.pop(context);
  }

  void _pick(VoidCallback change) {
    HapticFeedback.selectionClick();
    unawaited(FPGAudio.playSfx(FPGAudio.click));
    setState(change);
  }

  // ==========================================================
  // NAZWA / IKONA POZYCJI
  // ==========================================================

  String positionName(PlayerPosition position) {
    switch (position) {
      case PlayerPosition.goalkeeper: return 'BRAMKARZ';
      case PlayerPosition.defender: return 'OBROŃCA';
      case PlayerPosition.midfielder: return 'POMOCNIK';
      case PlayerPosition.winger: return 'SKRZYDŁOWY';
      case PlayerPosition.striker: return 'NAPASTNIK';
    }
  }

  IconData positionIcon(PlayerPosition position) {
    switch (position) {
      case PlayerPosition.goalkeeper: return Icons.sports_handball_outlined;
      case PlayerPosition.defender: return Icons.shield_outlined;
      case PlayerPosition.midfielder: return Icons.sync_alt_rounded;
      case PlayerPosition.winger: return Icons.bolt_outlined;
      case PlayerPosition.striker: return Icons.sports_soccer_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(title: Text('NOWA KARIERA'), backgroundColor: FPGTheme.bg),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: FPGDecor.heroCard(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PIERWSZY KROK', style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    SizedBox(height: 7),
                    Text('Stwórz swojego zawodnika', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    SizedBox(height: 6),
                    Text('Ten profil pójdzie z Tobą przez całą karierę — imię, pozycja i punkt startowy.', style: TextStyle(color: FPGTheme.muted)),
                  ]),
                ),
                SizedBox(height: 20),
                _section('TOŻSAMOŚĆ'),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: FPGDecor.glowCard(),
                  child: Column(children: [
                    _field(controller: firstNameController, label: 'Imię', icon: Icons.person_outline_rounded, validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wpisz imię.';
                      if (v.trim().length < 2) return 'Imię jest za krótkie.';
                      return null;
                    }),
                    SizedBox(height: 12),
                    _field(controller: lastNameController, label: 'Nazwisko', icon: Icons.badge_outlined, validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wpisz nazwisko.';
                      if (v.trim().length < 2) return 'Nazwisko jest za krótkie.';
                      return null;
                    }),
                    SizedBox(height: 12),
                    _field(controller: nationalityController, label: 'Narodowość', icon: Icons.flag_outlined, validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wpisz narodowość.';
                      return null;
                    }),
                  ]),
                ),
                SizedBox(height: 20),
                _section('PARAMETRY'),
                Row(children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: FPGDecor.glowCard(),
                      child: _field(
                        controller: ageController,
                        label: 'Wiek',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        bare: true,
                        validator: (v) {
                          final age = int.tryParse(v ?? '');
                          if (age == null) return 'Podaj wiek.';
                          if (age < 16 || age > 35) return '16–35 lat.';
                          return null;
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: FPGDecor.glowCard(),
                      child: _field(
                        controller: heightController,
                        label: 'Wzrost (cm)',
                        icon: Icons.height_rounded,
                        keyboardType: TextInputType.number,
                        bare: true,
                        validator: (v) {
                          final h = int.tryParse(v ?? '');
                          if (h == null) return 'Podaj wzrost.';
                          if (h < 150 || h > 220) return '150–220 cm.';
                          return null;
                        },
                      ),
                    ),
                  ),
                ]),
                SizedBox(height: 20),
                _section('POCZĄTKOWY POZIOM (OVR)'),
                Text('Wyższy start ułatwia debiut, ale zostawia mniej miejsca na rozwój.', style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [40, 45, 50, 55, 60, 65, 70].map((v) {
                    final selected = v == startingOverall;
                    return _ovrChip(v, selected);
                  }).toList(),
                ),
                SizedBox(height: 20),
                _section('POZYCJA NA BOISKU'),
                Column(
                  children: PlayerPosition.values.map((p) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: _positionTile(p),
                  )).toList(),
                ),
                SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _creating ? null : createPlayer,
                    icon: _creating
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: FPGTheme.isLight ? Colors.white : Colors.black))
                        : Icon(Icons.play_arrow_rounded),
                    label: Text(_creating ? 'TWORZĘ ZAWODNIKA…' : 'ROZPOCZNIJ KARIERĘ'),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Twój zawodnik rozpocznie karierę z podstawowymi statystykami. '
                  'Rozwój będzie zależał od treningów, meczów, formy oraz decyzji w trakcie kariery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FPGTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool bare = false,
    String? Function(String?)? validator,
  }) {
    final field = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        border: InputBorder.none,
        filled: false,
        isDense: bare,
        labelText: label,
        labelStyle: TextStyle(color: FPGTheme.muted, fontSize: 12, fontWeight: FontWeight.w700),
        prefixIcon: Icon(icon, color: FPGTheme.muted, size: 20),
      ),
      validator: validator,
    );
    return bare ? field : field;
  }

  Widget _ovrChip(int value, bool selected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pick(() => startingOverall = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? FPGTheme.accent.withValues(alpha: .14) : FPGTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? FPGTheme.accent : FPGTheme.cardBorder, width: selected ? 1.6 : 1),
          ),
          child: Text('$value OVR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: selected ? FPGTheme.accent : FPGTheme.textPrimary)),
        ),
      ),
    );
  }

  Widget _positionTile(PlayerPosition position) {
    final selected = position == selectedPosition;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pick(() => selectedPosition = position),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? FPGTheme.accent.withValues(alpha: .14) : FPGTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? FPGTheme.accent : FPGTheme.cardBorder, width: selected ? 1.6 : 1),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: selected ? FPGTheme.accent.withValues(alpha: .22) : FPGTheme.surface2,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(positionIcon(position), size: 19, color: selected ? FPGTheme.accent : FPGTheme.muted),
            ),
            SizedBox(width: 12),
            Text(positionName(position), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: selected ? FPGTheme.accent : FPGTheme.textPrimary)),
            Spacer(),
            if (selected) Icon(Icons.check_circle_rounded, color: FPGTheme.accent, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _section(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: FPGTheme.muted)),
    ),
  );
}
