class GameState {
  int year;
  int month;
  int day;

  int season;

  bool transferWindowSummer;
  bool transferWindowWinter;

  GameState({
    this.year = 2026,
    this.month = 7,
    this.day = 24,
    this.season = 2026,
    this.transferWindowSummer = true,
    this.transferWindowWinter = false,
  });

  void nextDay() {
    day++;

    final daysInMonth = _daysInCurrentMonth();

    if (day > daysInMonth) {
      day = 1;
      month++;
    }

    if (month > 12) {
      month = 1;
      year++;
    }

    // Football season follows 1 July -> 30 June, not the calendar year.
    // A save started on 23.08.2026 therefore remains season 2026
    // throughout the 2026/27 campaign and becomes season 2027 on 1 July.
    if (month == 7 && day == 1) {
      season = year;
    }

    _updateTransferWindows();
  }

  int _daysInCurrentMonth() {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeapYear(year)) {
      return 29;
    }
    return days[month - 1];
  }

  bool _isLeapYear(int value) {
    return value % 400 == 0 || (value % 4 == 0 && value % 100 != 0);
  }

  void _updateTransferWindows() {
    transferWindowSummer = month == 7 || month == 8;
    transferWindowWinter = month == 1;
  }

  String get dateString {
    final dayString = day.toString().padLeft(2, '0');
    final monthString = month.toString().padLeft(2, '0');

    return '$dayString.$monthString.$year';
  }

  // ==========================================================
  // SERIALIZACJA STANU KALENDARZA (część WorldSave)
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'month': month,
      'day': day,
      'season': season,
      'transferWindowSummer': transferWindowSummer,
      'transferWindowWinter': transferWindowWinter,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final value = json[key];
      return value is num ? value.toInt() : fallback;
    }

    bool readBool(String key, bool fallback) {
      final value = json[key];
      return value is bool ? value : fallback;
    }

    final year = readInt('year', 2026);
    final month = readInt('month', 7);
    final day = readInt('day', 24);
    final season = readInt('season', year);

    // LOAD preflight validates the calendar too, but keeping this factory
    // defensive prevents malformed legacy JSON from creating an invalid
    // state that later crashes days[month - 1] or DateTime calculations.
    final safeYear = year.clamp(2000, 9999).toInt();
    final safeMonth = month.clamp(1, 12).toInt();
    final maxDay = _daysInMonthFor(safeYear, safeMonth);
    final safeDay = day.clamp(1, maxDay).toInt();

    return GameState(
      year: safeYear,
      month: safeMonth,
      day: safeDay,
      season: season.clamp(2000, 9999).toInt(),
      transferWindowSummer: readBool('transferWindowSummer', safeMonth == 7 || safeMonth == 8),
      transferWindowWinter: readBool('transferWindowWinter', safeMonth == 1),
    );
  }

  static int _daysInMonthFor(int year, int month) {
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && (year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))) {
      return 29;
    }
    return days[month - 1];
  }
}
