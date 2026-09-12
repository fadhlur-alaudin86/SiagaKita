// Purpose: Unit tests verifying BadgeTierItem, BadgeCategoryProgress, MissionHistoryItem models, and localization.
// Data & Logic Flow: Asserts JSON serialization, type icons/labels, and bilingual dictionary parity.
// Key Components: badge_and_mission_history_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siagakita/core/localization/app_localization.dart';
import 'package:siagakita/core/models/badge_model.dart';
import 'package:siagakita/core/models/mission_history_model.dart';


void main() {
  group('Badge Models Test', () {
    test('BadgeTierItem deserialization and serialization', () {
      final json = {
        'id': 'tier-1',
        'level': 2,
        'threshold': 10,
        'description': 'Selesaikan 10 misi respon darurat',
        'icon_url': '/static/badges/tier2.png',
        'earned': true,
        'earned_at': '2026-09-12T10:00:00Z',
      };

      final item = BadgeTierItem.fromJson(json);

      expect(item.id, 'tier-1');
      expect(item.level, 2);
      expect(item.threshold, 10);
      expect(item.description, 'Selesaikan 10 misi respon darurat');
      expect(item.iconUrl, '/static/badges/tier2.png');
      expect(item.earned, isTrue);
      expect(item.earnedAt, '2026-09-12T10:00:00Z');

      final serialized = item.toJson();
      expect(serialized['id'], 'tier-1');
      expect(serialized['level'], 2);
      expect(serialized['threshold'], 10);
      expect(serialized['earned'], isTrue);
    });

    test('BadgeCategoryProgress deserialization with nested tiers', () {
      final json = {
        'badge_code': 'FIRST_RESPONDER',
        'badge_name': 'Pahlawan Pertama',
        'current_level': 1,
        'max_level': 5,
        'current_progress': 3,
        'next_threshold': 5,
        'tiers': [
          {
            'id': 'b1',
            'level': 1,
            'threshold': 1,
            'description': 'Respon pertama',
            'icon_url': '',
            'earned': true,
          },
          {
            'id': 'b2',
            'level': 2,
            'threshold': 5,
            'description': 'Respon ke-5',
            'icon_url': '',
            'earned': false,
          },
        ],
      };

      final cat = BadgeCategoryProgress.fromJson(json);

      expect(cat.badgeCode, 'FIRST_RESPONDER');
      expect(cat.badgeName, 'Pahlawan Pertama');
      expect(cat.currentLevel, 1);
      expect(cat.maxLevel, 5);
      expect(cat.currentProgress, 3);
      expect(cat.nextThreshold, 5);
      expect(cat.tiers.length, 2);
      expect(cat.tiers[0].earned, isTrue);
      expect(cat.tiers[1].earned, isFalse);

      final serialized = cat.toJson();
      expect(serialized['badge_code'], 'FIRST_RESPONDER');
      expect((serialized['tiers'] as List).length, 2);
    });
  });


  group('MissionHistoryItem Test', () {
    test('Deserializes mission history with duration and proof photo', () {
      final json = {
        'id': 'm-123',
        'incident_type': 'medical',
        'status': 'resolved',
        'response_status': 'completed',
        'address_detail': 'Jl. Malioboro No. 1',
        'accepted_at': '2026-09-12T08:00:00Z',
        'completed_at': '2026-09-12T08:14:00Z',
        'duration_minutes': 14,
        'proof_photo_url': '/uploads/proof123.jpg',
        'xp_earned': 100,
      };

      final mission = MissionHistoryItem.fromJson(json);

      expect(mission.id, 'm-123');
      expect(mission.incidentType, 'medical');
      expect(mission.status, 'resolved');
      expect(mission.responseStatus, 'completed');
      expect(mission.addressDetail, 'Jl. Malioboro No. 1');
      expect(mission.durationMinutes, 14);
      expect(mission.proofPhotoUrl, '/uploads/proof123.jpg');
      expect(mission.xpEarned, 100);

      // Verify helper getters
      expect(mission.typeIcon, Icons.medical_services);
      expect(mission.typeCode, '[Medis]');
      expect(mission.typeLabel, 'Medis / Kesehatan');

      final serialized = mission.toJson();
      expect(serialized['id'], 'm-123');
      expect(serialized['duration_minutes'], 14);
      expect(serialized['proof_photo_url'], '/uploads/proof123.jpg');
    });

    test('Handles null fields with graceful fallbacks', () {
      final json = {
        'id': 'm-999',
        'status': 'in_progress',
        'response_status': 'en_route',
        'accepted_at': '2026-09-12T09:00:00Z',
      };

      final mission = MissionHistoryItem.fromJson(json);

      expect(mission.id, 'm-999');
      expect(mission.incidentType, 'general');
      expect(mission.durationMinutes, isNull);
      expect(mission.proofPhotoUrl, isNull);
      expect(mission.xpEarned, 0);
      expect(mission.typeIcon, Icons.warning_amber);
    });
  });


  group('Localization Translation Parity for Badges', () {
    test('Badge dictionary translations in English', () {
      AppLocalization.currentLocale = AppLocalization.localeEn;

      expect(AppLocalization.translate('Pahlawan Pertama'), 'First Responder');
      expect(AppLocalization.translate('Bintang Relawan'), 'Star Volunteer');
      expect(AppLocalization.translate('Penjaga Malam'), 'Night Watch');
      expect(AppLocalization.translate('Respon Kilat'), 'Rapid Response');
      expect(AppLocalization.translate('Medis Siaga'), 'Guardian Healer');
      expect(AppLocalization.translate('Tutup'), 'Close');
      expect(AppLocalization.translate('Riwayat Misi Relawan'), 'Volunteer Mission History');
      expect(AppLocalization.translate('Lencana Relawan'), 'Volunteer Badges');
      expect(AppLocalization.translate('Terbuka'), 'Unlocked');
      expect(AppLocalization.translate('Terkunci'), 'Locked');

      // Reset locale back to Indonesian
      AppLocalization.currentLocale = AppLocalization.localeId;
      expect(AppLocalization.translate('Pahlawan Pertama'), 'Pahlawan Pertama');
    });
  });
}
