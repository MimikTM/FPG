class PlayerContract {
  // ==========================================================
  // KLUB
  // ==========================================================

  String clubId;

  // ==========================================================
  // KONTRAKT
  // ==========================================================

  int yearsRemaining;

  // Pensja tygodniowa
  double weeklySalary;

  // ==========================================================
  // WARTOŚĆ ZAWODNIKA
  // ==========================================================

  double marketValue;

  // ==========================================================
  // NUMER I STATUS W DRUŻYNIE
  // ==========================================================

  int squadNumber;

  String squadStatus;

  // ==========================================================
  // ZAUFANIE TRENERA
  // ==========================================================

  int managerTrust;

  // ==========================================================
  // KONSTRUKTOR
  // ==========================================================

  PlayerContract({
    required this.clubId,
    required this.yearsRemaining,
    required this.weeklySalary,
    required this.marketValue,
    required this.squadNumber,
    required this.squadStatus,
    this.managerTrust = 50,
  });


  Map<String, dynamic> toJson() => {
    'clubId': clubId,
    'yearsRemaining': yearsRemaining,
    'weeklySalary': weeklySalary,
    'marketValue': marketValue,
    'squadNumber': squadNumber,
    'squadStatus': squadStatus,
    'managerTrust': managerTrust,
  };

  factory PlayerContract.fromJson(Map<String, dynamic> json) => PlayerContract(
    clubId: json['clubId'] as String,
    yearsRemaining: (json['yearsRemaining'] as num?)?.toInt() ?? 1,
    weeklySalary: (json['weeklySalary'] as num?)?.toDouble() ?? 50,
    marketValue: (json['marketValue'] as num?)?.toDouble() ?? 0,
    squadNumber: (json['squadNumber'] as num?)?.toInt() ?? 1,
    squadStatus: json['squadStatus'] as String? ?? 'rotation',
    managerTrust: (json['managerTrust'] as num?)?.toInt() ?? 50,
  );

  // ==========================================================
  // CZY KONTRAKT JEST AKTYWNY?
  // ==========================================================

  bool get isActive {
    return yearsRemaining > 0;
  }

  // ==========================================================
  // ROCZNA PENSJA
  // ==========================================================

  double get yearlySalary {
    return weeklySalary * 52;
  }

  // ==========================================================
  // ZMIANA ZAUFANIA TRENERA
  // ==========================================================

  void changeManagerTrust(int amount) {
    managerTrust =
        (managerTrust + amount).clamp(0, 100);
  }

  // ==========================================================
  // ZMIANA STATUSU
  // ==========================================================

  void changeSquadStatus(String newStatus) {
    squadStatus = newStatus;
  }

  // ==========================================================
  // ZMIANA NUMERU
  // ==========================================================

  void changeSquadNumber(int newNumber) {
    if (newNumber < 1 || newNumber > 99) {
      return;
    }

    squadNumber = newNumber;
  }

  // ==========================================================
  // ZMIANA WARTOŚCI RYNKOWEJ
  // ==========================================================

  void updateMarketValue(double newValue) {
    marketValue = newValue.clamp(0, double.infinity).toDouble();
  }

  // ==========================================================
  // ZMIANA PENSJI
  // ==========================================================

  void updateSalary(double newSalary) {
    weeklySalary = newSalary.clamp(0, double.infinity).toDouble();
  }

  // ==========================================================
  // ZMNIEJSZENIE KONTRAKTU
  // ==========================================================

  void reduceContractYear() {
    if (yearsRemaining > 0) {
      yearsRemaining--;
    }
  }
}
