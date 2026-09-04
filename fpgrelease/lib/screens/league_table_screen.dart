import 'package:flutter/material.dart';
import '../core/game_engine.dart';
import '../core/fpg_theme.dart';

class LeagueTableScreen extends StatelessWidget {
  final GameEngine engine;

  LeagueTableScreen({
    super.key,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    // Pobranie aktualnej ligi gracza
    //
    // NAPRAWA: `engine.leagueEngine.standings` to Map<String, Standing>,
    // a ten ekran próbował go indeksować jak listę (`standings[index]`)
    // i odwoływał się do pola `clubName`, którego Standing w ogóle nie ma.
    // `.table` zwraca już posortowaną listę Standing.
    final player = engine.careerPlayer;
    final standings = engine.leagueEngine.table;

    return Scaffold(
      backgroundColor: FPGTheme.bg,
      appBar: AppBar(
        title: Text('Tabela Ligowa'),
        backgroundColor: FPGTheme.bg,
      ),
      body: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
          child: standings.isEmpty
              ? Center(
                  child: Text(
                    'Brak danych o tabeli ligowej.',
                    style: TextStyle(color: FPGTheme.muted),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: standings.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Nagłówek tabeli
                      return Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: FPGTheme.surface2,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 30, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, color: FPGTheme.textPrimary))),
                            Expanded(child: Text('Klub', style: TextStyle(fontWeight: FontWeight.bold, color: FPGTheme.textPrimary))),
                            SizedBox(width: 35, child: Text('M', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: FPGTheme.textPrimary))),
                            SizedBox(width: 35, child: Text('B', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: FPGTheme.textPrimary))),
                            SizedBox(width: 40, child: Text('PKT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent))),
                          ],
                        ),
                      );
                    }

                    final item = standings[index - 1];
                    final isPlayerClub = player != null && item.clubId == player.clubId;

                    final clubMatches = engine.clubs.where((c) => c.id == item.clubId).toList();
                    final clubName = clubMatches.isEmpty ? 'Nieznany klub' : clubMatches.first.name;

                    return Container(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isPlayerClub
                            ? Colors.green.withValues(alpha: 0.15)
                            : (index % 2 == 0 ? FPGTheme.surface2.withValues(alpha: 0.4) : Colors.transparent),
                        border: Border(
                          bottom: BorderSide(color: FPGTheme.cardBorder, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              '$index',
                              style: TextStyle(
                                fontWeight: isPlayerClub ? FontWeight.bold : FontWeight.normal,
                                color: isPlayerClub ? Colors.greenAccent : FPGTheme.muted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              clubName,
                              style: TextStyle(
                                fontWeight: isPlayerClub ? FontWeight.bold : FontWeight.normal,
                                color: FPGTheme.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 35,
                            child: Text(
                              '${item.played}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: FPGTheme.muted),
                            ),
                          ),
                          SizedBox(
                            width: 35,
                            child: Text(
                              '${item.goalsFor}:${item.goalsAgainst}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: FPGTheme.muted, fontSize: 12),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${item.points}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
