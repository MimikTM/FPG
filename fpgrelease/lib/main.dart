import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/fpg_theme.dart';
import 'core/game_settings.dart';
import 'core/audio_service.dart';
import 'core/beta_diagnostics.dart';
import 'core/game_engine.dart';
import 'screens/career_home_screen.dart';
import 'screens/club_selection_screen.dart';
import 'screens/create_player_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tutorial_screen.dart';
import 'widgets/fpg_animated.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep every startup dependency inside the guarded zone. A platform audio
  // plugin or preference channel must never prevent the app from reaching its
  // first frame on a beta device. Individual services also have safe fallbacks.
  runZonedGuarded(() async {
    await FPGTheme.loadSavedMode();
    await GameSettings.load();
    await FPGAudio.init();
    await BetaDiagnostics.install();
    runApp(FPGApp());
  }, (error, stack) {
    unawaited(BetaDiagnostics.record(
      type: 'zone_error',
      message: error.toString(),
      stack: stack.toString(),
    ));
  });
}















class BroadcastHud44 {
  String home = 'HOME';
  String away = 'AWAY';
  int homeScore = 0;
  int awayScore = 0;
  int minute = 0;
  int second = 0;
  String event = 'IDLE';
  String eventText = '';
  double eventIntensity = 0.0;
  double eventTime = 0.0;

  void setTeams(String homeName, String awayName) {
    home = homeName;
    away = awayName;
  }

  void setScore(int homeGoals, int awayGoals) {
    homeScore = homeGoals;
    awayScore = awayGoals;
  }

  void setClock(int matchMinute, int matchSecond) {
    minute = matchMinute.clamp(0, 130);
    second = matchSecond.clamp(0, 59);
  }

  void showEvent(String type, {String? text, double intensity = 1.0}) {
    event = type;
    eventText = text ?? type;
    eventIntensity = intensity.clamp(0.0, 1.0);
    eventTime = 2.4;
  }

  void tick(double dt) {
    final t = dt.clamp(0.0, 0.1);
    eventTime = (eventTime - t).clamp(0.0, 3.0);
    eventIntensity = (eventIntensity - t * 0.35).clamp(0.0, 1.0);
    if (eventTime <= 0.0) {
      event = 'IDLE';
      eventText = '';
      eventIntensity = 0.0;
    }
  }

  void reset() {
    home = 'HOME';
    away = 'AWAY';
    homeScore = 0;
    awayScore = 0;
    minute = 0;
    second = 0;
    event = 'IDLE';
    eventText = '';
    eventIntensity = 0.0;
    eventTime = 0.0;
  }
}

class DynamicCrowd43 {
  String mood = 'CALM';
  double density = 0.75;
  double energy = 0.25;
  double chant = 0.0;
  double wave = 0.0;

  void react(String event, {double strength = 1.0}) {
    final s = strength.clamp(0.0, 1.0);
    switch (event) {
      case 'ATTACK':
        mood = 'TENSION';
        energy = 0.55 + s * 0.25;
        chant = 0.15 + s * 0.35;
        break;
      case 'SHOT':
        mood = 'ROAR';
        energy = 0.75 + s * 0.25;
        chant = 0.35 + s * 0.4;
        break;
      case 'SAVE':
        mood = 'RELIEF';
        energy = 0.55 + s * 0.2;
        chant = 0.2;
        break;
      case 'GOAL':
        mood = 'CELEBRATION';
        energy = 1.0;
        chant = 0.85 + s * 0.15;
        wave = 1.0;
        break;
      case 'MISS':
        mood = 'GROAN';
        energy = 0.45 + s * 0.15;
        chant = 0.05;
        break;
      default:
        mood = 'CALM';
        energy = 0.2;
        chant = 0.0;
    }
  }

  void tick(double dt) {
    final t = dt.clamp(0.0, 0.1);
    energy = (energy - t * 0.18).clamp(0.0, 1.0);
    chant = (chant - t * 0.22).clamp(0.0, 1.0);
    wave = (wave - t * 1.2).clamp(0.0, 1.0);
    if (energy < 0.08) mood = 'CALM';
  }

  void reset() {
    mood = 'CALM';
    density = 0.75;
    energy = 0.25;
    chant = 0.0;
    wave = 0.0;
  }
}

class DayNightSystem42 {
  String phase = 'DAY';
  double progress = 0.5;
  double ambientLight = 1.0;
  double artificialLight = 0.0;
  double skyIntensity = 1.0;
  double transition = 0.0;

  void setPhase(String nextPhase, {double nextProgress = 0.5}) {
    phase = nextPhase;
    progress = nextProgress.clamp(0.0, 1.0);
    transition = 1.0;
    _recalculate();
  }

  void tick(double dt) {
    final t = dt.clamp(0.0, 0.1);
    transition = (transition - t * 0.45).clamp(0.0, 1.0);
  }

  void _recalculate() {
    switch (phase) {
      case 'DAWN':
        ambientLight = 0.58 + progress * 0.32;
        artificialLight = (1.0 - progress) * 0.45;
        skyIntensity = 0.55 + progress * 0.35;
        break;
      case 'EVENING':
        ambientLight = 0.9 - progress * 0.42;
        artificialLight = 0.15 + progress * 0.65;
        skyIntensity = 0.9 - progress * 0.45;
        break;
      case 'NIGHT':
        ambientLight = 0.42;
        artificialLight = 0.85;
        skyIntensity = 0.35;
        break;
      default:
        ambientLight = 1.0;
        artificialLight = 0.0;
        skyIntensity = 1.0;
    }
  }

  void reset() {
    phase = 'DAY';
    progress = 0.5;
    transition = 0.0;
    _recalculate();
  }
}

class WeatherSystem41 {
  String condition = 'CLEAR';
  double intensity = 0.0;
  double wind = 0.0;
  double visibility = 1.0;
  double transition = 0.0;

  void setWeather({
    required String nextCondition,
    double nextIntensity = 0.0,
    double nextWind = 0.0,
    double nextVisibility = 1.0,
  }) {
    condition = nextCondition;
    intensity = nextIntensity.clamp(0.0, 1.0);
    wind = nextWind.clamp(0.0, 1.0);
    visibility = nextVisibility.clamp(0.35, 1.0);
    transition = 1.0;
  }

  void tick(double dt) {
    transition = (transition - dt.clamp(0.0, 0.1) * 0.5).clamp(0.0, 1.0);
  }

  void reset() {
    condition = 'CLEAR';
    intensity = 0.0;
    wind = 0.0;
    visibility = 1.0;
    transition = 0.0;
  }
}

class StadiumSystem40 {
  String stadiumId = 'default_stadium';
  String stadiumName = 'HOME STADIUM';
  int capacity = 30000;
  double atmosphere = 0.65;
  double pitchScale = 1.0;

  void select({
    required String id,
    required String name,
    required int seats,
    double atmosphereLevel = 0.65,
    double scale = 1.0,
  }) {
    stadiumId = id;
    stadiumName = name;
    capacity = seats;
    atmosphere = atmosphereLevel.clamp(0.0, 1.0);
    pitchScale = scale.clamp(0.8, 1.2);
  }

  void reset() {
    stadiumId = 'default_stadium';
    stadiumName = 'HOME STADIUM';
    capacity = 30000;
    atmosphere = 0.65;
    pitchScale = 1.0;
  }
}

class UiReactions39 {
  String event = 'IDLE';
  String headline = '';
  double intensity = 0.0;
  double progress = 0.0;

  void trigger(String nextEvent, {String? message, double strength = 1.0}) {
    event = nextEvent;
    headline = message ?? nextEvent;
    intensity = strength.clamp(0.0, 1.0);
    progress = 0.0;
  }

  void tick(double dt) {
    final t = dt.clamp(0.0, 0.1);
    progress += t;
    intensity = (intensity - t * 0.9).clamp(0.0, 1.0);
    if (progress >= 1.6) {
      event = 'IDLE';
      headline = '';
      intensity = 0.0;
      progress = 0.0;
    }
  }

  void reset() {
    event = 'IDLE';
    headline = '';
    intensity = 0.0;
    progress = 0.0;
  }
}

class GoalCelebration38 {
  String phase = 'IDLE';
  double intensity = 0.0;
  double progress = 0.0;

  void start({double strength = 1.0}) {
    phase = 'IMPACT';
    intensity = strength.clamp(0.0, 1.0);
    progress = 0.0;
  }

  void tick(double dt) {
    final t = dt.clamp(0.0, 0.1);
    progress += t;
    if (progress < 0.16) {
      phase = 'IMPACT';
    } else if (progress < 0.75) {
      phase = 'CELEBRATION';
    } else if (progress < 1.35) {
      phase = 'TEAM_REACTION';
    } else if (progress < 1.75) {
      phase = 'PRESENTATION';
    } else {
      phase = 'RETURN';
      intensity = (intensity - t * 2.0).clamp(0.0, 1.0);
    }
    if (progress >= 2.0) {
      phase = 'IDLE';
      intensity = 0.0;
    }
  }

  void reset() {
    phase = 'IDLE';
    intensity = 0.0;
    progress = 0.0;
  }
}

class DynamicSfx37 {
  String current = 'none';
  double intensity = 0.0;
  double ducking = 0.0;

  void trigger(String event, {double strength = 1.0}) {
    current = event;
    intensity = strength.clamp(0.0, 1.0);
    ducking = (intensity * 0.65).clamp(0.0, 1.0);
  }

  void tick(double dt) {
    final t = dt.clamp(0.0, 0.1);
    intensity = (intensity - t * 1.8).clamp(0.0, 1.0);
    ducking = (ducking - t * 1.4).clamp(0.0, 1.0);
    if (intensity <= 0.02) current = 'none';
  }

  void reset() {
    current = 'none';
    intensity = 0.0;
    ducking = 0.0;
  }
}

class CrowdReactions36 {
  String state = 'CALM';
  double intensity = 0.0;
  double pulse = 0.0;

  void trigger(String event) {
    switch (event) {
      case 'danger':
        state = 'TENSION';
        intensity = 0.55;
        break;
      case 'shot':
        state = 'ROAR';
        intensity = 0.75;
        break;
      case 'save':
        state = 'RELIEF';
        intensity = 0.65;
        break;
      case 'goal':
        state = 'GOAL_ROAR';
        intensity = 1.0;
        break;
      case 'miss':
        state = 'GROAN';
        intensity = 0.45;
        break;
      default:
        state = 'CALM';
        intensity = 0.2;
    }
    pulse = 1.0;
  }

  void tick(double dt) {
    final t = dt.clamp(0.0, 0.1);
    intensity = (intensity - t * 0.28).clamp(0.0, 1.0);
    pulse = (pulse - t * 2.4).clamp(0.0, 1.0);
    if (intensity <= 0.02) state = 'CALM';
  }

  void reset() {
    state = 'CALM';
    intensity = 0.0;
    pulse = 0.0;
  }
}

class CameraImpact35 {
  double zoom = 1.0;
  double targetZoom = 1.0;
  double impact = 0.0;
  double timeLeft = 0.0;

  void trigger({
    double zoomAmount = 0.045,
    double impactAmount = 0.18,
    double duration = 0.22,
  }) {
    targetZoom = (1.0 + zoomAmount).clamp(1.0, 1.35);
    impact = impactAmount.clamp(0.0, 1.0);
    timeLeft = duration.clamp(0.02, 1.0);
  }

  void tick(double dt) {
    final t = dt.clamp(0.0, 0.1);
    if (timeLeft > 0.0) {
      timeLeft = (timeLeft - t).clamp(0.0, 1.0);
    }
    final desired = timeLeft > 0.0 ? targetZoom : 1.0;
    zoom += (desired - zoom) * (1.0 - math.exp(-t * 12.0));
    if (timeLeft <= 0.0) {
      impact += (0.0 - impact) * (1.0 - math.exp(-t * 10.0));
    }
  }

  void reset() {
    zoom = 1.0;
    targetZoom = 1.0;
    impact = 0.0;
    timeLeft = 0.0;
  }
}

class HitStop34 {
  double timeLeft = 0.0;
  double intensity = 0.0;

  bool get active => timeLeft > 0.0;

  void trigger({double duration = 0.055, double intensityValue = 1.0}) {
    timeLeft = duration.clamp(0.01, 0.25);
    intensity = intensityValue.clamp(0.0, 1.0);
  }

  bool tick(double dt) {
    if (timeLeft <= 0.0) {
      intensity = 0.0;
      return false;
    }
    timeLeft = (timeLeft - dt).clamp(0.0, 0.25);
    if (timeLeft <= 0.0) intensity = 0.0;
    return timeLeft > 0.0;
  }

  void reset() {
    timeLeft = 0.0;
    intensity = 0.0;
  }
}

class ScreenShake33 {
  double amount = 0.0;
  double timeLeft = 0.0;
  double phase = 0.0;

  void trigger({double strength = 0.25, double duration = 0.16}) {
    amount = strength.clamp(0.0, 1.0);
    timeLeft = duration.clamp(0.01, 1.0);
    phase = 0.0;
  }

  Offset tick(double dt) {
    if (timeLeft <= 0.0 || amount <= 0.0) return Offset.zero;
    timeLeft = (timeLeft - dt).clamp(0.0, 1.0);
    phase += dt * 72.0;
    final falloff = timeLeft <= 0.0 ? 0.0 : timeLeft;
    final x = math.sin(phase * 1.31) * amount * falloff;
    final y = math.cos(phase * 1.73) * amount * falloff;
    return Offset(x, y);
  }

  void reset() {
    amount = 0.0;
    timeLeft = 0.0;
    phase = 0.0;
  }
}

class GameFeelParticles32 {
  final List<Offset> sparks = <Offset>[];
  double burst = 0.0;

  void trigger({int count = 12}) {
    sparks.clear();
    for (var i = 0; i < count; i++) {
      final a = (i / count) * 6.283185307179586;
      sparks.add(Offset(math.cos(a), math.sin(a)));
    }
    burst = 1.0;
  }

  void tick(double dt) {
    burst = (burst - dt * 2.8).clamp(0.0, 1.0);
  }

  void reset() {
    sparks.clear();
    burst = 0.0;
  }
}

class RealtimeFeedback31 {
  String label = 'READY';
  double quality = 0.0;
  double timing = 0.0;
  double power = 0.0;
  double accuracy = 0.0;

  void reset() {
    label = 'READY';
    quality = timing = power = accuracy = 0.0;
  }

  void update({
    required double timingValue,
    required double powerValue,
    required double accuracyValue,
  }) {
    timing = timingValue.clamp(0.0, 1.0);
    power = powerValue.clamp(0.0, 1.0);
    accuracy = accuracyValue.clamp(0.0, 1.0);

    final score = (timing * 0.45) + (power * 0.20) + (accuracy * 0.35);
    quality = score;

    if (timing >= 0.92 && accuracy >= 0.90) {
      label = 'PERFECT';
    } else if (timing >= 0.72 && accuracy >= 0.70) {
      label = 'GOOD';
    } else if (timing < 0.35) {
      label = 'EARLY';
    } else if (timing < 0.58) {
      label = 'LATE';
    } else {
      label = 'MISS';
    }
  }
}

class FPGApp extends StatelessWidget {
  FPGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: FPGTheme.modeNotifier,
      builder: (context, _, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FPG - Football Player Game',
          theme: FPGTheme.themeData(),
          home: FPGLaunchScreen(),
          themeAnimationDuration: const Duration(milliseconds: 220),
          themeAnimationCurve: Curves.easeOutCubic,
        );
      },
    );
  }
}

/// Short branded launch screen shown on every cold start.
/// It intentionally uses the existing FPG palette rather than introducing
/// a separate visual identity.
class FPGLaunchScreen extends StatefulWidget {
  FPGLaunchScreen({super.key});

  @override
  State<FPGLaunchScreen> createState() => _FPGLaunchScreenState();
}

class _FPGLaunchScreenState extends State<FPGLaunchScreen>
    with SingleTickerProviderStateMixin {
  final BroadcastHud44 broadcastHud44 = BroadcastHud44();

  final DynamicCrowd43 dynamicCrowd43 = DynamicCrowd43();

  final DayNightSystem42 dayNightSystem42 = DayNightSystem42();

  final WeatherSystem41 weatherSystem41 = WeatherSystem41();

  final StadiumSystem40 stadiumSystem40 = StadiumSystem40();

  final UiReactions39 uiReactions39 = UiReactions39();

  final GoalCelebration38 goalCelebration38 = GoalCelebration38();

  final DynamicSfx37 dynamicSfx37 = DynamicSfx37();

  final CrowdReactions36 crowdReactions36 = CrowdReactions36();

  final CameraImpact35 cameraImpact35 = CameraImpact35();

  final HitStop34 hitStop34 = HitStop34();

  final ScreenShake33 screenShake33 = ScreenShake33();

  final GameFeelParticles32 gameFeelParticles32 = GameFeelParticles32();

  final RealtimeFeedback31 realtimeFeedback31 = RealtimeFeedback31();

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..forward();
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: .92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    FPGAudio.playMusic(FPGAudio.menuMusic);
    _navigationTimer = Timer(Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => GameSettings.tutorialCompleted ? FPGHomePage() : const TutorialScreen(),
          transitionDuration: Duration(milliseconds: 300),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _navigationTimer = null;
    _controller.dispose();
    super.dispose();
  }

  void updateRealtimeFeedback31({
    required double timing,
    required double power,
    required double accuracy,
  }) {
    setState(() {
      realtimeFeedback31.update(
        timingValue: timing,
        powerValue: power,
        accuracyValue: accuracy,
      );
    });
  }

  void triggerParticles32({int count = 12}) {
    setState(() {
      gameFeelParticles32.trigger(count: count);
    });
  }

  void triggerScreenShake33({
    double strength = 0.25,
    double duration = 0.16,
  }) {
    setState(() {
      screenShake33.trigger(
        strength: strength,
        duration: duration,
      );
    });
  }

  void triggerHitStop34({
    double duration = 0.055,
    double intensity = 1.0,
  }) {
    setState(() {
      hitStop34.trigger(
        duration: duration,
        intensityValue: intensity,
      );
    });
  }

  void triggerCameraImpact35({
    double zoomAmount = 0.045,
    double impactAmount = 0.18,
    double duration = 0.22,
  }) {
    setState(() {
      cameraImpact35.trigger(
        zoomAmount: zoomAmount,
        impactAmount: impactAmount,
        duration: duration,
      );
    });
  }

  void triggerCrowdReaction36(String event) {
    setState(() {
      crowdReactions36.trigger(event);
    });
  }

  void triggerDynamicSfx37(String event, {double strength = 1.0}) {
    setState(() {
      dynamicSfx37.trigger(event, strength: strength);
    });
  }

  void startGoalCelebration38({double strength = 1.0}) {
    setState(() {
      goalCelebration38.start(strength: strength);
    });
  }

  void triggerUiReaction39(
    String event, {
    String? message,
    double strength = 1.0,
  }) {
    setState(() {
      uiReactions39.trigger(
        event,
        message: message,
        strength: strength,
      );
    });
  }

  void selectStadium40({
    required String id,
    required String name,
    required int seats,
    double atmosphere = 0.65,
    double scale = 1.0,
  }) {
    setState(() {
      stadiumSystem40.select(
        id: id,
        name: name,
        seats: seats,
        atmosphereLevel: atmosphere,
        scale: scale,
      );
    });
  }

  void setWeather41({
    required String condition,
    double intensity = 0.0,
    double wind = 0.0,
    double visibility = 1.0,
  }) {
    setState(() {
      weatherSystem41.setWeather(
        nextCondition: condition,
        nextIntensity: intensity,
        nextWind: wind,
        nextVisibility: visibility,
      );
    });
  }

  void setDayNight42(String phase, {double progress = 0.5}) {
    setState(() {
      dayNightSystem42.setPhase(phase, nextProgress: progress);
    });
  }

  void triggerCrowd43(String event, {double strength = 1.0}) {
    setState(() {
      dynamicCrowd43.react(event, strength: strength);
    });
  }

  void updateBroadcastHud44({
    String? home,
    String? away,
    int? homeScore,
    int? awayScore,
    int? minute,
    int? second,
  }) {
    setState(() {
      if (home != null && away != null) {
        broadcastHud44.setTeams(home, away);
      }
      if (homeScore != null && awayScore != null) {
        broadcastHud44.setScore(homeScore, awayScore);
      }
      if (minute != null && second != null) {
        broadcastHud44.setClock(minute, second);
      }
    });
  }

  void showBroadcastEvent44(
    String type, {
    String? text,
    double intensity = 1.0,
  }) {
    setState(() {
      broadcastHud44.showEvent(
        type,
        text: text,
        intensity: intensity,
      );
    });
  }





























  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FPGTheme.bg,
      body: Stack(
        children: [
          _FPGAmbientBackground(),
          Center(
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FPGBrandMark(size: 104),
                    SizedBox(height: 22),
                    Text(
                      'FPG',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 7,
                        color: FPGTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Football Player Game',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                        color: FPGTheme.muted,
                      ),
                    ),
                    SizedBox(height: 34),
                    Text(
                      'creator by mEmmor',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .8,
                        color: FPGTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FPGHomePage extends StatefulWidget {
  FPGHomePage({super.key});

  @override
  State<FPGHomePage> createState() => _FPGHomePageState();
}

class _FPGHomePageState extends State<FPGHomePage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final GameEngine engine = GameEngine();
  bool loadingSave = false;
  late final AnimationController _homeController;
  late final Animation<double> _homeOpacity;
  late final Animation<Offset> _homeSlide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _homeOpacity = CurvedAnimation(parent: _homeController, curve: Curves.easeOut);
    _homeSlide = Tween<Offset>(
      begin: const Offset(0, .035),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _homeController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _homeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      // Auto-save can be disabled by the player. WorldSave serializes
      // concurrent snapshots and never needs broad Android storage access.
      if (GameSettings.autoSave) unawaited(engine.saveWorld());
    }
  }

  Future<void> loadSavedCareer() async {
    if (loadingSave) return;
    HapticFeedback.lightImpact();
    setState(() => loadingSave = true);
    try {
      final ok = await engine.loadWorld();
      if (!mounted) return;
      if (!ok) {
        _message('Nie znaleziono poprawnego zapisu kariery.');
        return;
      }
      if (engine.careerPlayer != null && engine.careerPlayer!.clubId != null) {
        _openCareerHome();
      } else if (engine.careerPlayer != null) {
        _openClubSelection();
      } else {
        _message('Zapis świata nie zawiera aktywnej kariery.');
      }
    } finally {
      if (mounted) setState(() => loadingSave = false);
    }
  }

  void _newCareer() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      FPGPageRoute(builder: (_) => CreatePlayerScreen(engine: engine)),
    ).then((_) {
      if (!mounted) return;
      if (engine.careerPlayer != null && engine.careerPlayer!.clubId == null) {
        _openClubSelection();
      }
    });
  }

  void _openClubSelection() {
    Navigator.push(
      context,
      FPGPageRoute(builder: (_) => ClubSelectionScreen(engine: engine)),
    );
  }

  void _openCareerHome() {
    Navigator.push(
      context,
      FPGPageRoute(builder: (_) => CareerHomeScreen(engine: engine)),
    );
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      FPGPageRoute(builder: (_) => SettingsScreen(engine: engine)),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FPGTheme.bg,
      body: Stack(
        children: [
          _FPGAmbientBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 520),
                child: FadeTransition(
                  opacity: _homeOpacity,
                  child: SlideTransition(
                    position: _homeSlide,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
                      child: Column(
                    children: [
                      SizedBox(height: 8),
                      _mainBrand(),
                      SizedBox(height: 34),
                      _mainMenuCard(),
                      SizedBox(height: 18),
                      _footer(),
                      ],
                    ),
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

  Widget _mainBrand() {
    return Column(
      children: [
        _FPGBrandMark(size: 82),
        SizedBox(height: 18),
        Text(
          'FPG',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 7,
            color: FPGTheme.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'FOOTBALL PLAYER GAME',
          style: TextStyle(
            color: FPGTheme.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }

  Widget _mainMenuCard() {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: FPGDecor.glowCard(accent: true).copyWith(
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [FPGTheme.accent, FPGTheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.sports_soccer_rounded,
                    color: FPGTheme.isLight ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MENU GŁÓWNE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: FPGTheme.muted,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Rozpocznij swoją karierę',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FPGTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6),
          _menuButton(
            icon: Icons.play_arrow_rounded,
            title: 'NOWA KARIERA',
            subtitle: 'Stwórz zawodnika i wybierz pierwszy klub',
            primary: true,
            onTap: _newCareer,
          ),
          _menuButton(
            icon: Icons.folder_open_rounded,
            title: 'KONTYNUUJ',
            subtitle: loadingSave ? 'Wczytywanie zapisu…' : 'Wróć do ostatnio zapisanej kariery',
            onTap: loadingSave ? null : loadSavedCareer,
            trailing: loadingSave
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FPGTheme.accent,
                    ),
                  )
                : Icon(Icons.chevron_right_rounded),
          ),
          _menuButton(
            icon: Icons.settings_outlined,
            title: 'USTAWIENIA',
            subtitle: 'Wygląd i opcje aplikacji',
            onTap: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _menuButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool primary = false,
    Widget? trailing,
  }) {
    final enabled = onTap != null;
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap();
                }
              : null,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: primary
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FPGTheme.accent.withValues(alpha: .22),
                        FPGTheme.secondary.withValues(alpha: .14),
                      ],
                    )
                  : null,
              color: primary ? null : FPGTheme.surface2.withValues(alpha: enabled ? .55 : .25),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: primary
                    ? FPGTheme.accent.withValues(alpha: .30)
                    : FPGTheme.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primary
                        ? FPGTheme.accent.withValues(alpha: .18)
                        : FPGTheme.surface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: enabled ? FPGTheme.accent : FPGTheme.muted,
                    size: 23,
                  ),
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: enabled ? FPGTheme.textPrimary : FPGTheme.muted,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: FPGTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.chevron_right_rounded, color: FPGTheme.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Text(
          'FPG — Football Player Game',
          style: TextStyle(
            color: FPGTheme.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'creator by mEmmor',
          style: TextStyle(
            color: FPGTheme.muted.withValues(alpha: .75),
            fontSize: 10,
            letterSpacing: .6,
          ),
        ),
      ],
    );
  }
}

class _FPGBrandMark extends StatelessWidget {
  final double size;
  _FPGBrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FPGTheme.accent, FPGTheme.secondary],
        ),
        borderRadius: BorderRadius.circular(size * .27),
        boxShadow: [
          BoxShadow(
            color: FPGTheme.accent.withValues(alpha: .18),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/fpg_logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.sports_soccer_rounded,
          size: size * .47,
          color: FPGTheme.isLight ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

class _FPGAmbientBackground extends StatelessWidget {
  _FPGAmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -150,
            right: -130,
            child: _glow(300, FPGTheme.accent.withValues(alpha: .07)),
          ),
          Positioned(
            bottom: -180,
            left: -150,
            child: _glow(360, FPGTheme.secondary.withValues(alpha: .055)),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
