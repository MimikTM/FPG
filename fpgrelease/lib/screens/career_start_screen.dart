import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';
import '../core/audio_service.dart';
import 'career_home_screen.dart';
import '../widgets/fpg_animated.dart';

class CareerStartScreen extends StatefulWidget {
  final GameEngine engine;
  CareerStartScreen({super.key, required this.engine});
  @override State<CareerStartScreen> createState() => _CareerStartScreenState();
}

class _CareerStartScreenState extends State<CareerStartScreen> with SingleTickerProviderStateMixin {
  int _years = 3;
  late TextEditingController _salary;
  int _shirt = 27;
  bool _starting = false;

  late final AnimationController _entrance;
  late final Animation<double> _fade;

  GameEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    final c = engine.careerPlayer?.contract;
    _years = c?.yearsRemaining ?? 3;
    _shirt = engine.careerPlayer?.shirtNumber ?? c?.squadNumber ?? 27;
    _salary = TextEditingController(text: (c?.weeklySalary ?? 0).toStringAsFixed(0));
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  }

  @override
  void dispose() { _salary.dispose(); _entrance.dispose(); super.dispose(); }

  Future<void> _start() async {
    final salary = double.tryParse(_salary.text.replaceAll(',', '.'));
    if (salary == null || !salary.isFinite || salary < 50) {
      HapticFeedback.heavyImpact();
      unawaited(FPGAudio.playSfx(FPGAudio.error));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wpisz prawidłową pensję tygodniową (min. 50).')));
      return;
    }
    setState(() => _starting = true);
    engine.configureCareerContract(years: _years, weeklySalary: salary, shirtNumber: _shirt);
    final saved = await engine.saveWorld();
    if (!mounted) return;
    if (!saved) {
      setState(() => _starting = false);
      HapticFeedback.heavyImpact();
      unawaited(FPGAudio.playSfx(FPGAudio.error));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kontrakt ustawiony, ale zapis się nie udał.')));
      return;
    }
    HapticFeedback.mediumImpact();
    unawaited(FPGAudio.playSfx(FPGAudio.success));
    if (!mounted) return;
    Navigator.pushReplacement(context, FPGPageRoute(builder: (_) => CareerHomeScreen(engine: engine)));
  }

  void _pick(VoidCallback change) {
    HapticFeedback.selectionClick();
    unawaited(FPGAudio.playSfx(FPGAudio.click));
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final player = engine.careerPlayer;
    if (player == null || player.contract == null || player.clubId == null) {
      return Scaffold(body: Center(child: Text('Nie znaleziono danych kariery.')));
    }
    final club = engine.careerClub;
    if (club == null) return Scaffold(body: Center(child: Text('Nie znaleziono klubu zawodnika.')));
    final contract = player.contract!;

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(title: Text('KONTRAKT DEBIUTANTA')),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: FPGDecor.heroCard(),
                child: Row(children: [
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [FPGTheme.accent, FPGTheme.secondary]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      player.firstName.isNotEmpty ? player.firstName[0] : '?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: FPGTheme.isLight ? Colors.white : Colors.black),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PIERWSZY PROFESJONALNY KONTRAKT', style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                      SizedBox(height: 6), Text(player.fullName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4), Text('${club.name} • OVR klubu ${club.overall}', style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
              SizedBox(height: 20),
              _section('DŁUGOŚĆ KONTRAKTU'),
              Row(
                children: [1, 2, 3, 4, 5].map((v) {
                  final selected = v == _years;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: v == 5 ? 0 : 8),
                      child: _chip(
                        label: '$v',
                        sub: v == 1 ? 'ROK' : 'LATA',
                        selected: selected,
                        onTap: () => _pick(() => _years = v),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              _section('PENSJA TYGODNIOWA'),
              Container(
                decoration: FPGDecor.glowCard(),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _salary,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                    prefixIcon: Icon(Icons.payments_outlined, color: FPGTheme.muted),
                    suffixText: 'zł / tydz.',
                    suffixStyle: TextStyle(color: FPGTheme.muted, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _section('NUMER KOSZULKI'),
              _shirtPicker(),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: FPGDecor.glowCard(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.shield_outlined, size: 18, color: FPGTheme.muted),
                    SizedBox(width: 8),
                    Text('TWOJA ROLA W KLUBIE', style: TextStyle(color: FPGTheme.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ]),
                  SizedBox(height: 8), Text(contract.squadStatus, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (contract.managerTrust / 100).clamp(0, 1),
                      minHeight: 6,
                      backgroundColor: FPGTheme.surface2,
                      color: FPGTheme.accent,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text('Zaufanie trenera ${contract.managerTrust}/100 • warunki możesz później renegocjować', style: TextStyle(color: FPGTheme.muted, fontSize: 11)),
                ]),
              ),
              SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _starting ? null : _start,
                  icon: _starting
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: FPGTheme.isLight ? Colors.white : Colors.black))
                      : Icon(Icons.handshake_outlined),
                  label: Text(_starting ? 'PODPISUJĘ…' : 'AKCEPTUJĘ I ZACZYNAM KARIERĘ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip({required String label, required String sub, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? FPGTheme.accent.withValues(alpha: .14) : FPGTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? FPGTheme.accent : FPGTheme.cardBorder, width: selected ? 1.6 : 1),
          ),
          child: Column(children: [
            Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: selected ? FPGTheme.accent : FPGTheme.textPrimary)),
            SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .8, color: FPGTheme.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _shirtPicker() {
    return Container(
      decoration: FPGDecor.glowCard(),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        _shirtStep(Icons.remove_rounded, () => _pick(() => _shirt = (_shirt - 1).clamp(1, 99))),
        Expanded(
          child: Column(children: [
            Text('#$_shirt', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: FPGTheme.accent)),
          ]),
        ),
        _shirtStep(Icons.add_rounded, () => _pick(() => _shirt = (_shirt + 1).clamp(1, 99))),
      ]),
    );
  }

  Widget _shirtStep(IconData icon, VoidCallback onTap) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(padding: EdgeInsets.all(12), child: Icon(icon, color: FPGTheme.muted)),
    ),
  );

  Widget _section(String text) => Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(bottom: 10), child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: FPGTheme.muted))));
}
