// -----------------------------------------------------------------------------
// Purpose:
// Standardized emergency contact relationship codes, list of choices, and
// bilingual localization helpers for civilian and volunteer profile management.
//
// Data & Logic Flow:
// 1. Receives raw relation code (parent, spouse, child, sibling, friend, other).
// 2. Maps the code to an AppLocalization dictionary key.
// 3. Returns the localized string matching the active BuildContext locale.
//
// Key Components:
// - EmergencyRelation: Class containing constant codes and localization getters.
// -----------------------------------------------------------------------------

import 'package:flutter/widgets.dart';
import 'package:siagakita/core/localization/app_localization.dart';

class EmergencyRelation {
  static const String parent = 'parent';
  static const String spouse = 'spouse';
  static const String child = 'child';
  static const String sibling = 'sibling';
  static const String friend = 'friend';
  static const String other = 'other';

  static const List<String> all = [
    parent,
    spouse,
    child,
    sibling,
    friend,
    other,
  ];

  static String getLabel(String? code, BuildContext context) {
    switch (code?.toLowerCase()) {
      case parent:
        return 'Orang Tua'.tr(context);
      case spouse:
        return 'Suami / Istri'.tr(context);
      case child:
        return 'Anak'.tr(context);
      case sibling:
        return 'Saudara'.tr(context);
      case friend:
        return 'Teman'.tr(context);
      case other:
        return 'Lainnya'.tr(context);
      default:
        return code ?? '';
    }
  }

  static String getIndonesianLabel(String code) {
    switch (code.toLowerCase()) {
      case parent:
        return 'Orang Tua';
      case spouse:
        return 'Suami / Istri';
      case child:
        return 'Anak';
      case sibling:
        return 'Saudara';
      case friend:
        return 'Teman';
      case other:
        return 'Lainnya';
      default:
        return code;
    }
  }
}
