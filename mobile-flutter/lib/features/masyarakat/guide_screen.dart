import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String _searchQuery = "";
  int? _expandedGuideId;

  final List<Map<String, dynamic>> _guides = [
    {
      "id": 1,
      "title": "Pendarahan Hebat",
      "type": "MEDIS",
      "steps": [
        "Tekan luka kuat-kuat dengan kain bersih.",
        "Tinggikan posisi luka di atas jantung jika memungkinkan.",
        "Jangan lepas kain pertama jika darah tembus, tumpuk dengan kain baru.",
        "Segera cari bantuan darurat.",
      ],
    },
    {
      "id": 2,
      "title": "Luka Bakar",
      "type": "MEDIS",
      "steps": [
        "Aliri area luka dengan air mengalir (bukan es) selama 15-20 menit.",
        "Lepaskan pakaian atau perhiasan di sekitar luka sebelum membengkak.",
        "Tutup luka secara longgar dengan plastik wrap atau kain bersih.",
        "Jangan pernah memecahkan lepuhan.",
      ],
    },
    {
      "id": 3,
      "title": "Tersedak (Dewasa)",
      "type": "MEDIS",
      "steps": [
        "Berdirilah di belakang korban dan peluk pinggangnya.",
        "Kepalkan satu tangan sedikit di atas pusarnya.",
        "Genggam kepalan dengan tangan satunya, lalu hentakkan ke atas dan ke dalam (Heimlich Maneuver).",
        "Ulangi sampai benda asing keluar.",
      ],
    },
    {
      "id": 4,
      "title": "Gempa Bumi",
      "type": "BENCANA",
      "steps": [
        "Lakukan Drop, Cover, Hold On (Merunduk, Berlindung di bawah meja yang kuat, Berpegangan).",
        "Jauhi jendela, kaca, dan perabotan yang bisa jatuh.",
        "Jika di luar, cari area terbuka jauh dari bangunan, pohon, dan tiang listrik.",
        "Jangan gunakan lift saat evakuasi.",
      ],
    },
  ];

  List<Map<String, dynamic>> _localizedGuides(BuildContext context) {
    return _guides.map((g) {
      return {
        ...g,
        'title': g['title'].toString().tr(context),
        'type': g['type'].toString().tr(context),
        'steps': (g['steps'] as List<String>)
            .map((s) => s.tr(context))
            .toList(),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final localizedGuides = _localizedGuides(context);
    final filteredGuides = localizedGuides
        .where(
          (g) =>
              g['title'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              g['type'].toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.onSurface.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.menu_book, color: colors.primary),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PANDUAN DARURAT'.tr(context),
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_user,
                                color: Colors.green,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Database Lokal Aktif (Offline/Online)'.tr(
                                  context,
                                ),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 5,
                              ),
                            ],
                    ),
                    child: TextField(
                      style: TextStyle(color: colors.onSurface, fontSize: 14),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: "Cari tindakan (mis: Luka Bakar)...".tr(
                          context,
                        ),
                        hintStyle: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: colors.onSurface.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filteredGuides.length,
                itemBuilder: (ctx, i) {
                  final guide = filteredGuides[i];
                  final isExpanded = _expandedGuideId == guide['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedGuideId = isExpanded ? null : guide['id'];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.onSurface.withValues(alpha: 0.1),
                        ),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 5,
                                ),
                              ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      guide['title'],
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      guide['type'],
                                      style: TextStyle(
                                        color: colors.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: isExpanded
                                      ? colors.primary
                                      : colors.onSurface.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Divider(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.1,
                                    ),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  ...List.generate(
                                    guide['steps'].length,
                                    (idx) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${idx + 1}. ',
                                            style: TextStyle(
                                              color: colors.onSurface
                                                  .withValues(alpha: 0.9),
                                              fontSize: 12,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              guide['steps'][idx],
                                              style: TextStyle(
                                                color: colors.onSurface
                                                    .withValues(alpha: 0.9),
                                                fontSize: 12,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
