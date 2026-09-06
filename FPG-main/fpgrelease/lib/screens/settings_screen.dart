import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/fpg_theme.dart';
import '../core/game_engine.dart';
import '../core/game_settings.dart';
import '../core/audio_service.dart';
import '../database/world_save.dart';
import '../core/beta_diagnostics.dart';
import 'tutorial_screen.dart';
import '../widgets/fpg_animated.dart';

class SettingsScreen extends StatefulWidget {
  final GameEngine? engine;

  const SettingsScreen({super.key, this.engine});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _setDifficulty(MiniGameDifficulty value) async {
    HapticFeedback.selectionClick();
    await GameSettings.setDifficulty(value);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final engine = widget.engine;
    if (engine == null) {
      _message('Brak aktywnej kariery do zapisania.');
      return;
    }
    setState(() => _busy = true);
    final ok = await engine.saveWorld();
    if (!mounted) return;
    setState(() => _busy = false);
    _message(ok ? 'Kariera została zapisana.' : 'Nie udało się zapisać kariery.', error: !ok);
  }

  Future<void> _deleteSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('USUNĄĆ ZAPIS?'),
        content: const Text(
          'Usunięta zostanie ostatnia zapisana kariera oraz kopia zapasowa. '
          'Tej operacji nie można cofnąć.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANULUJ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('USUŃ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final ok = await WorldSave.deleteSave();
    if (!mounted) return;
    setState(() => _busy = false);
    _message(ok ? 'Zapis został usunięty.' : 'Nie udało się usunąć zapisu.', error: !ok);
  }

  Future<void> _showDiagnostics() async {
    HapticFeedback.selectionClick();
    final file = await BetaDiagnostics.file();
    if (!mounted) return;
    if (file == null) {
      _message('Brak zapisanych błędów diagnostycznych.');
      return;
    }
    final lines = (await file.readAsLines());
    // Newest first, and capped so the dialog stays readable — this is a
    // debugging aid for testers, not a full log viewer.
    final recent = lines.reversed.take(20).join('\n\n');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DIAGNOSTYKA (OSTATNIE BŁĘDY)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              recent.isEmpty ? 'Plik diagnostyczny jest pusty.' : recent,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ZAMKNIJ')),
        ],
      ),
    );
  }

  Future<void> _openTutorial() async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      FPGPageRoute(builder: (_) => const TutorialScreen(manual: true)),
    );
  }

  Future<void> _testAudio(String asset, {required bool music}) async {
    HapticFeedback.selectionClick();
    if (music) {
      await FPGAudio.playMusic(asset);
    } else {
      await FPGAudio.playSfx(asset);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: FPGTheme.modeNotifier,
      builder: (context, isLight, _) {
        return Scaffold(
          backgroundColor: FPGTheme.bg,
          appBar: AppBar(title: const Text('USTAWIENIA')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _hero(),
              const SizedBox(height: 18),
              _section('ROZGRYWKA'),
              _gameplayCard(),
              const SizedBox(height: 22),
              _section('WYGLĄD'),
              _themeCard(context, isLight),
              const SizedBox(height: 22),
              _section('AUDIO'),
              _audioCard(),
              const SizedBox(height: 22),
              _section('POMOC'),
            Card(child: ListTile(leading: Icon(Icons.school_outlined, color: FPGTheme.accent), title: const Text('Tutorial'), subtitle: const Text('Uruchom interaktywne wprowadzenie do kariery'), trailing: const Icon(Icons.chevron_right_rounded), onTap: _openTutorial)),
            const SizedBox(height: 14),
            _section('DANE'),
              _dataCard(),
              const SizedBox(height: 22),
              _section('O APLIKACJI'),
              _infoCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
          color: FPGTheme.muted,
        ),
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(20),
        decoration: FPGDecor.heroCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'USTAWIENIA',
              style: TextStyle(
                color: FPGTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Dostosuj swoją karierę',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: FPGTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ustawienia są zapisywane lokalnie w pamięci aplikacji.',
              style: TextStyle(color: FPGTheme.textPrimary.withValues(alpha: .7)),
            ),
          ],
        ),
      );

  Widget _gameplayCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: FPGDecor.glowCard(),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.speed_rounded, color: FPGTheme.accent),
              title: const Text('Poziom trudności', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                '${GameSettings.difficulty.label} — ${GameSettings.difficulty.description}',
                style: TextStyle(color: FPGTheme.muted, fontSize: 12),
              ),
            ),
            DropdownButtonFormField<MiniGameDifficulty>(
              initialValue: GameSettings.difficulty,
              decoration: const InputDecoration(
                labelText: 'Trudność minigier',
                border: OutlineInputBorder(),
              ),
              items: MiniGameDifficulty.values
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) _setDifficulty(value);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatyczny zapis', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Zapis po kluczowych zmianach i po meczu.'),
              value: GameSettings.autoSave,
              onChanged: (v) async {
                await GameSettings.setAutoSave(v);
                if (mounted) setState(() {});
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wibracje'),
              value: GameSettings.vibrations,
              onChanged: (v) async {
                await GameSettings.setVibrations(v);
                if (mounted) setState(() {});
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Potwierdzanie decyzji'),
              subtitle: const Text('Dodatkowe potwierdzenie przy ryzykownych akcjach.'),
              value: GameSettings.confirmDecisions,
              onChanged: (v) async {
                await GameSettings.setConfirmDecisions(v);
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      );


  Widget _audioCard() => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        decoration: FPGDecor.glowCard(),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.music_note_rounded, color: FPGTheme.accent),
              const SizedBox(width: 12),
              Expanded(child: Text('Muzyka', style: TextStyle(fontWeight: FontWeight.w900, color: FPGTheme.textPrimary))),
              Text('${GameSettings.musicVolume.round()}%', style: TextStyle(color: FPGTheme.muted, fontWeight: FontWeight.w700)),
            ]),
            Slider(
              value: GameSettings.musicVolume,
              min: 0, max: 100, divisions: 20,
              onChanged: (v) async {
                await GameSettings.setMusicVolume(v);
                await FPGAudio.setMusicVolume(v);
                if (v > 0) await FPGAudio.playSfx(FPGAudio.click);
                if (mounted) setState(() {});
              },
            ),
            Row(children: [
              Icon(Icons.graphic_eq_rounded, color: FPGTheme.accent),
              const SizedBox(width: 12),
              Expanded(child: Text('SFX', style: TextStyle(fontWeight: FontWeight.w900, color: FPGTheme.textPrimary))),
              Text('${GameSettings.sfxVolume.round()}%', style: TextStyle(color: FPGTheme.muted, fontWeight: FontWeight.w700)),
            ]),
            Slider(
              value: GameSettings.sfxVolume,
              min: 0, max: 100, divisions: 20,
              onChanged: (v) async {
                await GameSettings.setSfxVolume(v);
                await FPGAudio.setSfxVolume(v);
                await FPGAudio.playSfx(FPGAudio.click);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _testAudio(FPGAudio.careerMusic, music: true),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('TEST MUZYKI'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _testAudio(FPGAudio.click, music: false),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('TEST SFX'),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Własne pliki podmienisz w assets/audio/music i assets/audio/sfx, bez zmiany kodu. Zachowaj nazwy plików.',
                style: TextStyle(color: FPGTheme.muted, fontSize: 11, height: 1.35),
              ),
            ),
          ],
        ),
      );

  Widget _themeCard(BuildContext context, bool isLight) => Container(
        padding: const EdgeInsets.all(6),
        decoration: FPGDecor.glowCard(),
        child: Column(
          children: [
            _themeOption(
              context: context,
              label: 'CIEMNY',
              subtitle: 'Domyślny, wysoki kontrast',
              icon: Icons.dark_mode_rounded,
              selected: !isLight,
              onTap: () {
                HapticFeedback.selectionClick();
                FPGTheme.setLight(false);
              },
            ),
            Divider(height: 1, color: FPGTheme.cardBorder),
            _themeOption(
              context: context,
              label: 'JASNY',
              subtitle: 'Jasne tło, ciemny tekst',
              icon: Icons.light_mode_rounded,
              selected: isLight,
              onTap: () {
                HapticFeedback.selectionClick();
                FPGTheme.setLight(true);
              },
            ),
          ],
        ),
      );

  Widget _themeOption({
    required BuildContext context,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? FPGTheme.accent.withValues(alpha: .16) : FPGTheme.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: selected ? FPGTheme.accent : FPGTheme.muted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: FPGTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? FPGTheme.accent : FPGTheme.muted,
              ),
            ],
          ),
        ),
      );

  Widget _dataCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: FPGDecor.glowCard(),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(_busy ? 'PRZETWARZANIE…' : 'ZAPISZ GRĘ'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _deleteSave,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('USUŃ ZAPIS'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _showDiagnostics,
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('POKAŻ BŁĘDY DIAGNOSTYCZNE'),
              ),
            ),
          ],
        ),
      );

  Widget _infoCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: FPGDecor.glowCard(),
        child: Row(
          children: [
            Icon(Icons.sports_soccer, color: FPGTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FPG — Football Player Game',
                    style: TextStyle(fontWeight: FontWeight.w800, color: FPGTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '0.9.0 — Release Candidate',
                    style: TextStyle(color: FPGTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
