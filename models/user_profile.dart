class UserProfile {
  final String name;
  final Gender gender;
  final DateTime createdAt;

  UserProfile({
    required this.name,
    required this.gender,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Vokativ (5. pád) pro české oslovení
  String get vocative {
    if (name.isEmpty) return 'uživateli';

    final lowerName = name.toLowerCase();

    // Mužské jméno
    if (gender == Gender.male) {
      // Končí na -a (Honza → Honzo)
      if (lowerName.endsWith('a')) {
        return '${name.substring(0, name.length - 1)}o';
      }
      // Končí na konsonant (Marek → Marku, Pavel → Pavle)
      else if (_endsWithConsonant(lowerName)) {
        if (lowerName.endsWith('el')) {
          return '${name.substring(0, name.length - 2)}le';
        } else if (lowerName.endsWith('ek')) {
          return '${name.substring(0, name.length - 2)}ku';
        } else {
          return '${name}e';
        }
      }
      return name;
    }

    // Ženské jméno
    else {
      // Končí na -a (Jana → Jano, Petra → Petro)
      if (lowerName.endsWith('a')) {
        return '${name.substring(0, name.length - 1)}o';
      }
      return name;
    }
  }

  // Helper - končí jméno na souhlásku?
  bool _endsWithConsonant(String name) {
    if (name.isEmpty) return false;
    final lastChar = name[name.length - 1];
    const vowels = [
      'a',
      'e',
      'i',
      'o',
      'u',
      'y',
      'á',
      'é',
      'í',
      'ó',
      'ú',
      'ů',
      'ý'
    ];
    return !vowels.contains(lastChar);
  }

  // Oslovení podle času
  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 10) {
      return 'Dobré ráno, $vocative';
    } else if (hour < 18) {
      return 'Ahoj, $vocative';
    } else {
      return 'Dobrý večer, $vocative';
    }
  }

  // Krátké oslovení (pro notifikace)
  String get shortGreeting => 'Ahoj, $vocative';

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String,
      gender: Gender.values.firstWhere(
        (g) => g.name == json['gender'],
        orElse: () => Gender.other,
      ),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  UserProfile copyWith({
    String? name,
    Gender? gender,
  }) {
    return UserProfile(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      createdAt: createdAt,
    );
  }
}

enum Gender {
  male,
  female,
  other;

  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Muž';
      case Gender.female:
        return 'Žena';
      case Gender.other:
        return 'Jiné';
    }
  }
}
