class IAQCalculator {
  // Nastavení váhy (75% plyn, 25% vlhkost)
  static const double gasWeight = 0.75;
  static const double humWeight = 0.25;

  // Ideální vlhkost je 40 %
  static const double humReference = 40.0;

  /// Vypočítá IAQ Index (0-500)
  /// [gasResistance] - v Ohmech z BME680
  /// [humidity] - v % z BME680
  /// [gasBaseline] - nejvyšší naměřený odpor za posledních 24h (čistý vzduch)
  static double calculateIAQ(
      double gasResistance, double humidity, double gasBaseline) {
    // 1. Výpočet skóre vlhkosti (čím blíž k 40%, tím lépe)
    double humScore;
    if (humidity >= humReference) {
      humScore = (100 - humidity) / (100 - humReference) * (humWeight * 100);
    } else {
      humScore = (humidity / humReference) * (humWeight * 100);
    }

    // 2. Výpočet skóre plynu (poměr k baseline)
    double gasScore = (gasResistance / gasBaseline) * (gasWeight * 100);
    if (gasScore > (gasWeight * 100)) gasScore = gasWeight * 100;

    // 3. Celkové procentuální skóre (0-100%, kde 100 je nejlepší)
    double totalPercent = humScore + gasScore;

    // 4. Přepočet na IAQ Index (0-500, kde 0 je nejlepší)
    // Inverze: (100 - procenta) * 5
    double iaqIndex = (100 - totalPercent) * 5;

    return iaqIndex.clamp(0.0, 500.0);
  }

  /// Pomocná metoda pro interpretaci výsledku
  static String getIAQStatus(double iaq) {
    if (iaq <= 50) return "Výborný";
    if (iaq <= 100) return "Dobrý";
    if (iaq <= 150) return "Mírně znečištěný";
    if (iaq <= 200) return "Znečištěný";
    if (iaq <= 250) return "Velmi znečištěný";
    if (iaq <= 350) return "Špatný";
    return "Velmi špatný";
  }
}
