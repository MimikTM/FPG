import 'package:flutter/material.dart';

import '../core/game_engine.dart';
import '../models/player.dart';
import '../simulation/news_engine.dart';
import '../simulation/media_world_engine.dart';
import '../core/fpg_theme.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../core/audio_service.dart';
import '../widgets/fpg_animated.dart';

/// Ekran newsów / mediów społecznościowych.
///
/// Ten plik wcześniej w ogóle nie istniał, mimo że career_home_screen.dart
/// go importował i próbował z niego korzystać (`NewsScreen(engine: engine)`)
/// — to jeden z powodów, dla których gra się nie kompilowała.
class NewsScreen extends StatefulWidget {
  final GameEngine engine;

  NewsScreen({
    super.key,
    required this.engine,
  });

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with SingleTickerProviderStateMixin {
  List<NewsItem> _feed = [];
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
    _generateFeed();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _generateFeed() {
    final careerPlayer = widget.engine.careerPlayer;

    if (careerPlayer == null || careerPlayer.clubId == null) {
      _feed = [];
      return;
    }

    final clubMatches = widget.engine.clubs.where((c) => c.id == careerPlayer.clubId).toList();
    if (clubMatches.isEmpty) {
      _feed = [];
      return;
    }
    final club = clubMatches.first;

    // NewsEngine operuje na modelu Player (a nie PlayerCareer), więc
    // budujemy lekki obiekt-adapter z danych kariery gracza.
    final adapterPlayer = Player(
      id: careerPlayer.id,
      name: careerPlayer.fullName,
      age: careerPlayer.age,
      position: careerPlayer.position,
      overall: careerPlayer.overall,
      potential: careerPlayer.potential,
      pace: careerPlayer.pace,
      shooting: careerPlayer.shooting,
      passing: careerPlayer.passing,
      dribbling: careerPlayer.dribbling,
      defending: careerPlayer.defending,
      physical: careerPlayer.physical,
      value: careerPlayer.contract?.marketValue ?? 0,
      weeklyWage: careerPlayer.contract?.weeklySalary ?? 0,
      clubId: careerPlayer.clubId,
    );

    final state = widget.engine.state;

    _feed = NewsEngine.generateFeed(
      player: adapterPlayer,
      playerClub: club,
      currentDate: DateTime(state.year, state.month, state.day),
    );
  }

  Widget _playerProfileCard() {
    final career = widget.engine.careerPlayer;
    if (career == null) return SizedBox.shrink();
    return Container(
      decoration: FPGDecor.glowCard(accent: true),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PLAYER PROFILE', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _profileStat('FAME', career.fame),
                _profileStat('REPUTACJA', career.reputation),
                _profileStat('KIBICE', career.fanSupport),
                _profileStat('MARKA', career.marketability),
                _profileStat('SPONSOR', career.sponsorTier),
              ],
            ),
            SizedBox(height: 10),
            Text('Presja medialna: ${career.mediaPressure}/100'),
            SizedBox(height: 4),
            Text('Zainteresowanie agentów: ${career.agentAttention}/100  •  Popyt na koszulki: ${career.shirtDemand}/100'),
            Text('Zaproszenia medialne: ${career.interviewInvites}  •  Wartość marketingowa: ${career.marketingValue}/100'),
            if (career.sponsorTier > 0)
              Text('Umowa sponsorska: poziom ${career.sponsorTier}  •  przychód: ${career.sponsorIncome}'),
          ],
        ),
      ),
    );
  }

  Widget _profileStat(String label, int value) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9)),
      ],
    );
  }

  Color _avatarColor(String type) {
    switch (type) {
      case 'troll':
        return Colors.redAccent;
      case 'fan':
        return Colors.greenAccent;
      case 'insider':
        return Colors.orangeAccent;
      case 'stat':
        return Colors.blueAccent;
      default:
        return FPGTheme.muted;
    }
  }

  IconData _avatarIcon(String type) {
    switch (type) {
      case 'troll':
        return Icons.mood_bad;
      case 'fan':
        return Icons.favorite;
      case 'insider':
        return Icons.visibility;
      case 'stat':
        return Icons.bar_chart;
      default:
        return Icons.newspaper;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: Text('FPG NEWS'),
        backgroundColor: FPGTheme.bg,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.selectionClick();
              unawaited(FPGAudio.playSfx(FPGAudio.click));
              setState(() {
                _generateFeed();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _entrance,
          child: ListView(
            padding: EdgeInsets.all(12),
            children: [
              _playerProfileCard(),
              SizedBox(height: 10),
              _mediaSection(),
              SizedBox(height: 10),
              ..._feed.map(_socialCard),
            ],
          ),
        ),
      ),
    );
  }
  Widget _mediaSection() {
    final stories = widget.engine.worldEngine.mediaWorldEngine.latest.take(12).toList();
    if (stories.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'ŚWIAT / MEDIA',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
        ),
        ...stories.map((story) => Container(
              margin: EdgeInsets.only(bottom: 8),
              decoration: FPGDecor.glowCard(),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: story.heat >= 70
                      ? Colors.redAccent.withValues(alpha:  .18)
                      : Colors.blueAccent.withValues(alpha:  .18),
                  child: Icon(
                    story.type == 'rumour' ? Icons.visibility : Icons.newspaper,
                    color: story.heat >= 70 ? Colors.redAccent : Colors.blueAccent,
                    size: 18,
                  ),
                ),
                title: Text(story.title),
                subtitle: Text('${story.source} • ${story.body}'),
                isThreeLine: true,
              ),
            )),
      ],
    );
  }

  Widget _socialCard(NewsItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: FPGDecor.glowCard(),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: _avatarColor(item.avatarType).withValues(alpha:  0.2),
              child: Icon(_avatarIcon(item.avatarType), color: _avatarColor(item.avatarType), size: 18),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(item.authorName, style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Expanded(child: Text(item.authorHandle, overflow: TextOverflow.ellipsis, style: TextStyle(color: FPGTheme.muted, fontSize: 12))),
                  ]),
                  SizedBox(height: 6),
                  Text(item.content),
                  SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.favorite_border, size: 14, color: FPGTheme.muted),
                    SizedBox(width: 4),
                    Text('${item.likes}', style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
                    SizedBox(width: 16),
                    Icon(Icons.repeat, size: 14, color: FPGTheme.muted),
                    SizedBox(width: 4),
                    Text('${item.retweets}', style: TextStyle(color: FPGTheme.muted, fontSize: 12)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
