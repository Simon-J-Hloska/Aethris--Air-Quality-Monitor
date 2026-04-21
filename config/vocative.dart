class CzechVocative {
  static String getVocative(String name) {
    if (name.isEmpty) return name;

    String trimmed = name.trim();
    String n = trimmed.toLowerCase();

    // 1. GENDER DETECTION (Improved)
    bool isFemale = _isWoman(n);

    // 2. FEMALE RULES
    if (isFemale) {
      if (n.endsWith('a')) {
        return "${trimmed.substring(0, trimmed.length - 1)}o"; // Anna -> Anno, Eliška -> Eliško
      }
      if (n.endsWith('ia') || n.endsWith('ie')) {
        return trimmed; // Maria -> Maria, Marie -> Marie
      }
      if (n.endsWith('ice')) {
        return "${trimmed.substring(0, trimmed.length - 1)}i"; // Alice -> Alici
      }
      return trimmed; // Dagmar, Ester stay same
    }

    // 3. MALE RULES

    // Special case: -us (Latin names like Genius, Marius, Julius)
    if (n.endsWith('us')) {
      return "${trimmed.substring(0, trimmed.length - 2)}e"; // Julius -> Julie (or Juliu)
    }

    // Special case: -es (Hercules -> Herkule)
    if (n.endsWith('es')) {
      return "${trimmed.substring(0, trimmed.length - 2)}e";
    }

    // Endings that drop the vowel (Pavel -> Pavle, Petr -> Petře)
    if (n.endsWith('el')) {
      // Only drop if it's a typical Czech name ending
      return "${trimmed.substring(0, trimmed.length - 2)}le";
    }

    if (n.endsWith('er')) {
      return "${trimmed.substring(0, trimmed.length - 2)}ře"; // Petr -> Petře
    }

    // Softening R -> ŘE (for those not caught by 'er')
    if (n.endsWith('r')) {
      // Logic: Most Czech names ending in R soften to ŘE (Petr, Alexandr)
      // Foreign names often just take E (Arthur -> Arthure)
      return "${trimmed.substring(0, trimmed.length - 1)}ře";
    }

    // Hard Consonants -> U
    if (n.endsWith('h') ||
        n.endsWith('k') ||
        n.endsWith('g') ||
        n.endsWith('ch')) {
      return "${trimmed}u"; // Luděk -> Luďku, Marek -> Marku, Oleg -> Olegu
    }

    // Soft Consonants -> I
    if (n.endsWith('š') ||
        n.endsWith('ž') ||
        n.endsWith('č') ||
        n.endsWith('ř') ||
        n.endsWith('c') ||
        n.endsWith('j') ||
        n.endsWith('ď') ||
        n.endsWith('ť') ||
        n.endsWith('ň')) {
      return "${trimmed}i"; // Tomáš -> Tomáši, Matěj -> Matěji, Miloš -> Miloši
    }

    // Names ending in -A (usually hypocorisms)
    if (n.endsWith('a')) {
      return "${trimmed.substring(0, trimmed.length - 1)}o"; // Honza -> Honzo, Jirka -> Jirko
    }

    // Default for most male names (Jakub, Martin, Filip)
    return "${trimmed}e";
  }

  static bool _isWoman(String name) {
    // Standard female endings
    if (name.endsWith('a') ||
        name.endsWith('á') ||
        name.endsWith('ová') ||
        name.endsWith('ie')) {
      // Male exceptions ending in 'a'
      final maleExceptions = [
        'honza',
        'jirka',
        'vláďa',
        'míša',
        'pája',
        'saša',
        'matěja',
        'míra',
        'kuba'
      ];
      if (maleExceptions.contains(name)) return false;
      return true;
    }

    // Female names ending in consonants (Ester, Miriam, Dagmar)
    final femaleConsonants = ['ester', 'dagmar', 'miriam', 'beatrice', 'alice'];
    if (femaleConsonants.contains(name)) return true;

    return false;
  }
}
