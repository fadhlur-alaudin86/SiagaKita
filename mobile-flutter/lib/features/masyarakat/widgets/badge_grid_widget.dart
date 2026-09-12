// Purpose: UI widget displaying multi-level volunteer gamification badges, category progress, and tier milestones.
// Data & Logic Flow: Fetches badge status via UserService.getVolunteerBadges, renders badge category progress cards, and presents interactive tier details in a bottom sheet.
// Key Components: BadgeGridWidget, _BadgeDetailSheet.

import 'package:flutter/material.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/models/badge_model.dart';
import '../../../core/services/user_service.dart';

class BadgeGridWidget extends StatefulWidget {
  final String accessToken;

  const BadgeGridWidget({super.key, required this.accessToken});

  @override
  State<BadgeGridWidget> createState() => _BadgeGridWidgetState();
}

class _BadgeGridWidgetState extends State<BadgeGridWidget> {
  List<BadgeCategoryProgress> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBadges();
  }

  Future<void> _fetchBadges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final badges = await UserService.getVolunteerBadges(widget.accessToken);
      if (mounted) {
        setState(() {
          _categories = badges;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? Colors.white60 : Colors.black54;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0D1B3E);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Memuat lencana...'.tr(context),
                  style: TextStyle(color: hintColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Text(
              'Gagal memuat lencana'.tr(context),
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _fetchBadges,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Coba Lagi'.tr(context)),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.military_tech_rounded,
              color: Colors.amber.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Lencana Relawan'.tr(context).toUpperCase(),
              style: TextStyle(
                color: hintColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return _buildCategoryCard(
              context,
              cat,
              isDark,
              primaryTextColor,
              hintColor,
              cardColor,
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    BadgeCategoryProgress cat,
    bool isDark,
    Color primaryTextColor,
    Color hintColor,
    Color cardColor,
  ) {
    final isMax = cat.currentLevel >= cat.maxLevel && cat.maxLevel > 0;
    final progressFraction = isMax
        ? 1.0
        : (cat.nextThreshold != null && cat.nextThreshold! > 0)
        ? (cat.currentProgress / cat.nextThreshold!).clamp(0.0, 1.0)
        : 0.0;

    final categoryColor = _getCategoryColor(cat.badgeCode);
    final categoryIcon = _getCategoryIcon(cat.badgeCode);

    return InkWell(
      onTap: () => _showBadgeDetailSheet(context, cat, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cat.currentLevel > 0
                ? categoryColor.withValues(alpha: 0.3)
                : (isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cat.currentLevel > 0
                        ? categoryColor.withValues(alpha: 0.15)
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cat.currentLevel > 0
                        ? 'Lv ${cat.currentLevel}'
                        : 'Belum Ada'.tr(context),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: cat.currentLevel > 0 ? categoryColor : hintColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              cat.badgeName.tr(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: primaryTextColor,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isMax
                          ? 'Maksimal'.tr(context)
                          : '${cat.currentProgress}/${cat.nextThreshold ?? 1}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMax ? Colors.green : hintColor,
                        fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      '${(progressFraction * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? Colors.white12
                        : categoryColor.withValues(alpha: 0.12),
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetailSheet(
    BuildContext context,
    BadgeCategoryProgress cat,
    bool isDark,
  ) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0D1B3E);
    final hintColor = isDark ? Colors.white60 : Colors.black54;
    final categoryColor = _getCategoryColor(cat.badgeCode);
    final categoryIcon = _getCategoryIcon(cat.badgeCode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcon,
                          color: categoryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.badgeName.tr(context),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${'Level'.tr(context)} ${cat.currentLevel} / ${cat.maxLevel} • ${cat.currentProgress} ${'Respon Selesai'.tr(context)}',
                              style: TextStyle(fontSize: 12, color: hintColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DAFTAR TINGKAT'.tr(context),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: hintColor,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: cat.tiers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final tier = cat.tiers[idx];
                        return _buildTierItemTile(
                          ctx,
                          tier,
                          isDark,
                          primaryTextColor,
                          hintColor,
                          categoryColor,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.grey.shade100,
                          foregroundColor: primaryTextColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: Text(
                          'Tutup'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTierItemTile(
    BuildContext context,
    BadgeTierItem tier,
    bool isDark,
    Color primaryTextColor,
    Color hintColor,
    Color categoryColor,
  ) {
    final isEarned = tier.earned;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEarned
            ? (isDark
                  ? categoryColor.withValues(alpha: 0.12)
                  : categoryColor.withValues(alpha: 0.06))
            : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEarned
              ? categoryColor.withValues(alpha: 0.3)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEarned
                  ? Colors.green.withValues(alpha: 0.15)
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEarned ? Icons.check_circle : Icons.lock_outline,
              color: isEarned ? Colors.green : hintColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${'Level'.tr(context)} ${tier.level}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${tier.threshold} ${'Respon'.tr(context)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  tier.description.tr(context),
                  style: TextStyle(fontSize: 11, color: hintColor),
                ),
                if (tier.earnedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${'Terbuka:'.tr(context)} ${_formatDate(tier.earnedAt!)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isEarned
                  ? Colors.green.withValues(alpha: 0.15)
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isEarned ? 'Terbuka'.tr(context) : 'Terkunci'.tr(context),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isEarned ? Colors.green : hintColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String badgeCode) {
    return switch (badgeCode) {
      'FIRST_RESPONDER' => const Color(0xFF3B82F6),
      'STAR_VOLUNTEER' => const Color(0xFFF59E0B),
      'NIGHT_WATCH' => const Color(0xFF8B5CF6),
      'RAPID_RESPONSE' => const Color(0xFFEF4444),
      'GUARDIAN_HEALER' => const Color(0xFF10B981),
      _ => const Color(0xFF6366F1),
    };
  }

  IconData _getCategoryIcon(String badgeCode) {
    return switch (badgeCode) {
      'FIRST_RESPONDER' => Icons.verified_user_outlined,
      'STAR_VOLUNTEER' => Icons.star_rate_rounded,
      'NIGHT_WATCH' => Icons.nightlight_round,
      'RAPID_RESPONSE' => Icons.bolt_rounded,
      'GUARDIAN_HEALER' => Icons.healing_rounded,
      _ => Icons.military_tech_rounded,
    };
  }

  String _formatDate(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoStr;
    }
  }
}
