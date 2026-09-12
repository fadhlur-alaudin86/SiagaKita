// Purpose: Data models representing gamification badges, category progression, and tier milestones for volunteers.
// Data & Logic Flow: Raw JSON from GET /volunteer/badges is deserialized into BadgeCategoryProgress with embedded BadgeTierItem objects.
// Key Components: BadgeTierItem (individual tier milestone), BadgeCategoryProgress (category aggregation and current standing).

class BadgeTierItem {
  final String id;
  final int level;
  final int threshold;
  final String description;
  final String iconUrl;
  final bool earned;
  final String? earnedAt;

  const BadgeTierItem({
    required this.id,
    required this.level,
    required this.threshold,
    required this.description,
    required this.iconUrl,
    required this.earned,
    this.earnedAt,
  });

  factory BadgeTierItem.fromJson(Map<String, dynamic> json) => BadgeTierItem(
    id: json['id'] as String? ?? '',
    level: (json['level'] as num?)?.toInt() ?? 1,
    threshold: (json['threshold'] as num?)?.toInt() ?? 1,
    description: json['description'] as String? ?? '',
    iconUrl: json['icon_url'] as String? ?? '',
    earned: json['earned'] as bool? ?? false,
    earnedAt: json['earned_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'level': level,
    'threshold': threshold,
    'description': description,
    'icon_url': iconUrl,
    'earned': earned,
    'earned_at': earnedAt,
  };
}

class BadgeCategoryProgress {
  final String badgeCode;
  final String badgeName;
  final int currentLevel;
  final int maxLevel;
  final int currentProgress;
  final int? nextThreshold;
  final List<BadgeTierItem> tiers;

  const BadgeCategoryProgress({
    required this.badgeCode,
    required this.badgeName,
    required this.currentLevel,
    required this.maxLevel,
    required this.currentProgress,
    this.nextThreshold,
    required this.tiers,
  });

  static const Map<String, String> defaultBadgeNames = {
    'FIRST_RESPONDER': 'Pahlawan Pertama',
    'STAR_VOLUNTEER': 'Bintang Relawan',
    'NIGHT_WATCH': 'Penjaga Malam',
    'RAPID_RESPONSE': 'Respon Kilat',
    'GUARDIAN_HEALER': 'Medis Siaga',
  };

  factory BadgeCategoryProgress.fromJson(Map<String, dynamic> json) {
    final rawTiers = json['tiers'] as List<dynamic>? ?? [];
    final code = json['badge_code'] as String? ?? '';
    final name = json['badge_name'] as String? ?? '';
    final resolvedName = name.isNotEmpty
        ? name
        : (defaultBadgeNames[code] ?? code);

    return BadgeCategoryProgress(
      badgeCode: code,
      badgeName: resolvedName,
      currentLevel: (json['current_level'] as num?)?.toInt() ?? 0,
      maxLevel: (json['max_level'] as num?)?.toInt() ?? 1,
      currentProgress: (json['current_progress'] as num?)?.toInt() ?? 0,
      nextThreshold: (json['next_threshold'] as num?)?.toInt(),
      tiers: rawTiers
          .map((e) => BadgeTierItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'badge_code': badgeCode,
    'badge_name': badgeName,
    'current_level': currentLevel,
    'max_level': maxLevel,
    'current_progress': currentProgress,
    'next_threshold': nextThreshold,
    'tiers': tiers.map((t) => t.toJson()).toList(),
  };
}
