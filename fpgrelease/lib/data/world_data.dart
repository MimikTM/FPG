import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';

/// Seed świata FPG — sezon 2026/27.
///
/// Dane ligowe są rozdzielone od logiki symulacji. Dzięki temu awanse/spadki,
/// terminarze i AI mogą pracować na pełnym polskim piramidowym świecie.
class WorldData {
  static final leagues = <League>[
    League(id: 'pol_ek', name: 'Ekstraklasa', country: 'Polska', level: 1),
    League(id: 'pol_1liga', name: 'Betclic 1 Liga', country: 'Polska', level: 2),
    League(id: 'pol_2liga', name: 'Betclic 2 Liga', country: 'Polska', level: 3),
    League(id: 'pol_3liga_1', name: 'Betclic 3 Liga — Grupa I', country: 'Polska', level: 4),
    League(id: 'pol_3liga_2', name: 'Betclic 3 Liga — Grupa II', country: 'Polska', level: 4),
    League(id: 'pol_3liga_3', name: 'Betclic 3 Liga — Grupa III', country: 'Polska', level: 4),
    League(id: 'pol_3liga_4', name: 'Betclic 3 Liga — Grupa IV', country: 'Polska', level: 4),
  ];

  static final clubs = <Club>[
    ..._ekstraklasa,
    ..._firstLiga,
    ..._secondLiga,
    ..._thirdLigaGroup1,
    ..._thirdLigaGroup2,
    ..._thirdLigaGroup3,
    ..._thirdLigaGroup4,
  ];

  static Club _club({
    required String id,
    required String name,
    required String leagueId,
    required int overall,
    int budget = 2500000,
    int reputation = 55,
    int financialHealth = 72,
    int youthFocus = 60,
    int transferActivity = 50,
    int boardPressure = 50,
    int managerReputation = 55,
  }) {
    final manager = 'mgr_$id';
    return Club(
      id: id,
      name: name,
      country: 'Polska',
      leagueId: leagueId,
      overall: overall,
      budget: budget,
      reputation: reputation,
      financialHealth: financialHealth,
      minimumSigningOverall: (overall - 5).clamp(40, 85).toInt(),
      preferredMinAge: 18,
      preferredMaxAge: 30,
      youthFocus: youthFocus,
      transferActivity: transferActivity,
      boardPressure: boardPressure,
      managerQuality: managerReputation,
      fanSupport: reputation,
      tacticalIdentity: 50 + (overall - 50).clamp(0, 25),
      academyQuality: youthFocus,
      academyReputation: youthFocus,
      academyTechnical: youthFocus,
      academyPhysical: 50 + ((overall - 50) ~/ 2),
      academyCreative: youthFocus,
      academyTactical: youthFocus,
      academyLocal: 70,
      academyInternational: 35,
      stability: financialHealth,
      managerStyle: youthFocus >= 80 ? 'possession' : transferActivity >= 72 ? 'direct' : boardPressure >= 70 ? 'high_press' : overall <= 60 && reputation <= 58 ? 'low_block' : (overall + reputation) % 3 == 0 ? 'counter' : 'balanced',
      managerId: manager,
      managerName: 'Trener $name',
      managerReputation: managerReputation,
      boardConfidence: 70,
      historicalReputation: reputation,
    );
  }

  // PKO BP Ekstraklasa 2026/27 — 18 klubów.
  static final _ekstraklasa = <Club>[
    _club(id: 'cracovia', name: 'Cracovia', leagueId: 'pol_ek', overall: 67, budget: 10000000, reputation: 68),
    _club(id: 'gks_katowice', name: 'GKS Katowice', leagueId: 'pol_ek', overall: 66, budget: 8500000, reputation: 62),
    _club(id: 'gornik', name: 'Górnik Zabrze', leagueId: 'pol_ek', overall: 67, budget: 9000000, reputation: 65),
    _club(id: 'jagiellonia', name: 'Jagiellonia Białystok', leagueId: 'pol_ek', overall: 70, budget: 15000000, reputation: 68, youthFocus: 80),
    _club(id: 'korona', name: 'Korona Kielce', leagueId: 'pol_ek', overall: 64, budget: 6500000, reputation: 60),
    _club(id: 'lech', name: 'Lech Poznań', leagueId: 'pol_ek', overall: 74, budget: 30000000, reputation: 78, youthFocus: 82, managerReputation: 75),
    _club(id: 'legia', name: 'Legia Warszawa', leagueId: 'pol_ek', overall: 73, budget: 30000000, reputation: 80, managerReputation: 75, boardPressure: 75),
    _club(id: 'motor', name: 'Motor Lublin', leagueId: 'pol_ek', overall: 63, budget: 7000000, reputation: 58),
    _club(id: 'piast', name: 'Piast Gliwice', leagueId: 'pol_ek', overall: 67, budget: 8000000, reputation: 62),
    _club(id: 'pogon', name: 'Pogoń Szczecin', leagueId: 'pol_ek', overall: 69, budget: 14000000, reputation: 67),
    _club(id: 'radomiak', name: 'Radomiak Radom', leagueId: 'pol_ek', overall: 64, budget: 6500000, reputation: 58),
    _club(id: 'rakow', name: 'Raków Częstochowa', leagueId: 'pol_ek', overall: 72, budget: 18000000, reputation: 72, managerReputation: 68),
    _club(id: 'slask', name: 'Śląsk Wrocław', leagueId: 'pol_ek', overall: 66, budget: 8500000, reputation: 64),
    _club(id: 'wieczysta', name: 'Wieczysta Kraków', leagueId: 'pol_ek', overall: 64, budget: 12000000, reputation: 58, transferActivity: 75),
    _club(id: 'wisla_krakow', name: 'Wisła Kraków', leagueId: 'pol_ek', overall: 68, budget: 10000000, reputation: 72),
    _club(id: 'wisla_plock', name: 'Wisła Płock', leagueId: 'pol_ek', overall: 65, budget: 7000000, reputation: 61),
    _club(id: 'widzew', name: 'Widzew Łódź', leagueId: 'pol_ek', overall: 67, budget: 8500000, reputation: 68),
    _club(id: 'zaglebie', name: 'Zagłębie Lubin', leagueId: 'pol_ek', overall: 68, budget: 12000000, reputation: 66),
  ];

  // Betclic 1 Liga 2026/27 — 18 klubów.
  static final _firstLiga = <Club>[
    _club(id: 'arka', name: 'Arka Gdynia', leagueId: 'pol_1liga', overall: 66, budget: 8500000, reputation: 65),
    _club(id: 'brk_bet', name: 'Bruk-Bet Termalica Nieciecza', leagueId: 'pol_1liga', overall: 65, budget: 8000000, reputation: 62),
    _club(id: 'chrobry', name: 'Chrobry Głogów', leagueId: 'pol_1liga', overall: 61, budget: 4500000, reputation: 54),
    _club(id: 'lechia_gdansk', name: 'Lechia Gdańsk', leagueId: 'pol_1liga', overall: 64, budget: 7000000, reputation: 65),
    _club(id: 'lks', name: 'ŁKS Łódź', leagueId: 'pol_1liga', overall: 64, budget: 6500000, reputation: 67),
    _club(id: 'miedz', name: 'Miedź Legnica', leagueId: 'pol_1liga', overall: 64, budget: 6500000, reputation: 60),
    _club(id: 'odra_opole', name: 'Odra Opole', leagueId: 'pol_1liga', overall: 59, budget: 4000000, reputation: 53),
    _club(id: 'podbeskidzie', name: 'Podbeskidzie Bielsko-Biała', leagueId: 'pol_1liga', overall: 60, budget: 4500000, reputation: 57),
    _club(id: 'pogon_grodzisk', name: 'Pogoń Grodzisk Mazowiecki', leagueId: 'pol_1liga', overall: 57, budget: 3000000, reputation: 48, youthFocus: 70),
    _club(id: 'pogon_siedlce', name: 'Pogoń Siedlce', leagueId: 'pol_1liga', overall: 57, budget: 3200000, reputation: 49),
    _club(id: 'polonia_bytom', name: 'Polonia Bytom', leagueId: 'pol_1liga', overall: 58, budget: 3500000, reputation: 52),
    _club(id: 'polonia_w', name: 'Polonia Warszawa', leagueId: 'pol_1liga', overall: 60, budget: 5000000, reputation: 56),
    _club(id: 'puszcza', name: 'Puszcza Niepołomice', leagueId: 'pol_1liga', overall: 61, budget: 4500000, reputation: 56),
    _club(id: 'ruch', name: 'Ruch Chorzów', leagueId: 'pol_1liga', overall: 64, budget: 7000000, reputation: 67, youthFocus: 72),
    _club(id: 'stal_mielec', name: 'Stal Mielec', leagueId: 'pol_1liga', overall: 63, budget: 5500000, reputation: 59),
    _club(id: 'stal_rzeszow', name: 'Stal Rzeszów', leagueId: 'pol_1liga', overall: 61, budget: 5200000, reputation: 55),
    _club(id: 'unia_skierniewice', name: 'Unia Skierniewice', leagueId: 'pol_1liga', overall: 56, budget: 2600000, reputation: 45, youthFocus: 75),
    _club(id: 'warta', name: 'Warta Poznań', leagueId: 'pol_1liga', overall: 59, budget: 4000000, reputation: 55),
  ];

  // Betclic 2 Liga 2026/27 — 18 klubów. Skład zgodny z sezonem 2026/27.
  static final _secondLiga = <Club>[
    _club(id: 'znicz', name: 'Znicz Pruszków', leagueId: 'pol_2liga', overall: 60, budget: 4200000, reputation: 55),
    _club(id: 'resovia', name: 'Resovia', leagueId: 'pol_2liga', overall: 59, budget: 3800000, reputation: 54),
    _club(id: 'podhale', name: 'Podhale Nowy Targ', leagueId: 'pol_2liga', overall: 55, budget: 2200000, reputation: 44),
    _club(id: 'slask_ii', name: 'Śląsk II Wrocław', leagueId: 'pol_2liga', overall: 56, budget: 2500000, reputation: 48, youthFocus: 88),
    _club(id: 'legia_ii', name: 'Legia II Warszawa', leagueId: 'pol_2liga', overall: 57, budget: 2600000, reputation: 50, youthFocus: 90),
    _club(id: 'stal_stalowa_wola', name: 'Stal Stalowa Wola', leagueId: 'pol_2liga', overall: 57, budget: 2800000, reputation: 49),
    _club(id: 'swit', name: 'Świt Szczecin', leagueId: 'pol_2liga', overall: 55, budget: 2200000, reputation: 44),
    _club(id: 'gornik_leczna', name: 'Górnik Łęczna', leagueId: 'pol_2liga', overall: 62, budget: 5000000, reputation: 58),
    _club(id: 'zawisza', name: 'Zawisza Bydgoszcz', leagueId: 'pol_2liga', overall: 56, budget: 2800000, reputation: 52),
    _club(id: 'sokol_kleczew', name: 'Sokół Kleczew', leagueId: 'pol_2liga', overall: 54, budget: 1800000, reputation: 42),
    _club(id: 'sandecja', name: 'Sandecja Nowy Sącz', leagueId: 'pol_2liga', overall: 59, budget: 3500000, reputation: 56),
    _club(id: 'hutnik', name: 'Hutnik Kraków', leagueId: 'pol_2liga', overall: 58, budget: 3000000, reputation: 51),
    _club(id: 'lechia_zg', name: 'Lechia Zielona Góra', leagueId: 'pol_2liga', overall: 54, budget: 1800000, reputation: 43),
    _club(id: 'rekord', name: 'Rekord Bielsko-Biała', leagueId: 'pol_2liga', overall: 56, budget: 2500000, reputation: 46, youthFocus: 80),
    _club(id: 'avia', name: 'Avia Świdnik', leagueId: 'pol_2liga', overall: 54, budget: 1900000, reputation: 43),
    _club(id: 'olimpia_gr', name: 'Olimpia Grudziądz', leagueId: 'pol_2liga', overall: 55, budget: 2100000, reputation: 46),
    _club(id: 'chojniczanka', name: 'Chojniczanka Chojnice', leagueId: 'pol_2liga', overall: 57, budget: 2700000, reputation: 51),
    _club(id: 'gks_tychy', name: 'GKS Tychy', leagueId: 'pol_2liga', overall: 63, budget: 5000000, reputation: 58),
  ];

  // 3 Liga: cztery grupy po 18 klubów. Rezerwy są pełnoprawnymi klubami świata,
  // ale ich AI nie może promować ich ponad reguły PZPN — obsłuży to WorldEngine.
  static final _thirdLigaGroup1 = _third('pol_3liga_1', [
    'Pelikan Łowicz','KTS Weszło','Mazovia Mińsk Mazowiecki','Olimpia Zambrów','Polonia Lidzbark Warmiński','ŁKS Łomża','Wigry Suwałki','Widzew II Łódź','ŁKS II Łódź','Warta Sieradz','Lechia Tomaszów Mazowiecki','Mławianka Mława','Ząbkovia Ząbki','Świt Nowy Dwór Mazowiecki','Wisła Płock II','Jagiellonia II Białystok','GKS Bełchatów','Legionovia Legionowo',
  ]);
  static final _thirdLigaGroup2 = _third('pol_3liga_2', [
    'Chemik Bydgoszcz','Wda Świecie','Elana Toruń','Kotwica Kórnik','Bałtyk Koszalin','Gedania Gdańsk','Grom Nowy Staw','Polonia Środa Wielkopolska','Unia Swarzędz','Noteć Czarnków','Lipno Stęszew','KKS Kalisz','Victoria Września','Flota Świnoujście','Błękitni Stargard','Pogoń Mogilno','Zawisza II Bydgoszcz','Lech II Poznań',
  ]);
  static final _thirdLigaGroup3 = _third('pol_3liga_3', [
    'Zagłębie Lubin II','Barycz Sułów','Górnik Polkowice','Miedź Legnica II','Ślęza Wrocław','Karkonosze Jelenia Góra','Stilon Gorzów Wielkopolski','Odra Bytom Odrzański','Stal Brzeg','ROW 1964 Rybnik','Raków II Częstochowa','Goczałkowice-Zdrój','Carina Gubin','Warta Gorzów Wielkopolski','Polonia Nysa','Sparta Katowice','MKS Kluczbork','Górnik II Zabrze',
  ]);
  static final _thirdLigaGroup4 = _third('pol_3liga_4', [
    'Hetman Zamość','Wieczysta II Kraków','JKS Jarosław','AKS 1947 Busko-Zdrój','Moravia Morawica','Chełmianka Chełm','Podlasie Biała Podlaska','Wiślanie Skawina','Wisła Kraków II','Siarka Tarnobrzeg','Wisłoka Dębica','Pogoń Sokół-Lubaczów','Sokół Kolbuszowa Dolna','KSZO Ostrowiec Świętokrzyski','Korona Kielce II','Star Starachowice','Czarni Połaniec','Naprzód Jędrzejów',
  ]);

  static List<Club> _third(String leagueId, List<String> names) {
    return [
      for (var i = 0; i < names.length; i++)
        _club(
          id: '${leagueId}_${i + 1}',
          name: names[i],
          leagueId: leagueId,
          overall: 48 + (i % 9),
          budget: 900000 + ((i % 7) * 180000),
          reputation: 38 + (i % 14),
          youthFocus: 55 + (i % 30),
        ),
    ];
  }

  static final players = <Player>[
    Player(id: 'test_player_1', name: 'Jan Kowalski', age: 19, position: PlayerPosition.striker, overall: 68, potential: 84, pace: 78, shooting: 72, passing: 58, dribbling: 70, defending: 25, physical: 65, value: 2500000, weeklyWage: 8000, clubId: 'lech'),
    Player(id: 'test_player_2', name: 'Michał Nowak', age: 22, position: PlayerPosition.midfielder, overall: 71, potential: 80, pace: 67, shooting: 60, passing: 78, dribbling: 73, defending: 58, physical: 70, value: 4000000, weeklyWage: 12000, clubId: 'legia'),
  ];
}
