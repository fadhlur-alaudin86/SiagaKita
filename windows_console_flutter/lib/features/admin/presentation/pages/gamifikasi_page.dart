import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/localization/app_localization.dart';

class GamifikasiPage extends StatelessWidget {
  final String token;
  const GamifikasiPage({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Master Data Gamifikasi'.tr(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            indicatorColor: const Color(0xFFFF7418),
            labelColor: const Color(0xFFFF7418),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Rank (XP Otomatis)'.tr(context)),
              Tab(text: 'Badges (Pemberian Manual)'.tr(context)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _RankTab(token: token),
                _BadgesTab(token: token),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TAB: RANKS ─────────────────────────────────────────────────────────────

class _RankTab extends StatefulWidget {
  final String token;
  const _RankTab({required this.token});

  @override
  State<_RankTab> createState() => _RankTabState();
}

class _RankTabState extends State<_RankTab> {
  List<RankModel> _ranks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminApiService.getRanks(widget.token);
    if (mounted) {
      setState(() {
        _ranks = data;
        _loading = false;
      });
    }
  }

  Future<void> _showForm({RankModel? existing}) async {
    final isBaseRank = existing != null && existing.minExp == 0;
    final nameCtrl = TextEditingController(text: existing?.rankName ?? '');
    final xpCtrl = TextEditingController(
      text: existing?.minExp.toString() ?? '0',
    );
    final iconCtrl = TextEditingController(text: existing?.iconUrl ?? '');
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2537),
          title: Text(
            (existing == null ? 'Tambah Rank Baru' : 'Edit Rank').tr(context),
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                _FormField(
                  controller: nameCtrl,
                  label: 'Nama Rank'.tr(context),
                  hint: 'Contoh: Relawan Ahli',
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: xpCtrl,
                  label: 'Minimum XP'.tr(context),
                  hint: '1000',
                  numeric: true,
                  enabled: !isBaseRank,
                  helperText: isBaseRank
                      ? 'Rank dasar memiliki batas minimum 0 XP dan tidak dapat diubah.'
                            .tr(context)
                      : null,
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: iconCtrl,
                  label: 'Icon URL'.tr(context),
                  hint: 'URL gambar',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Batal'.tr(context),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7418),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final xpParsed = int.tryParse(xpCtrl.text.trim());

                if (name.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Nama rank wajib diisi'.tr(context);
                  });
                  return;
                }
                if (xpParsed == null) {
                  setDialogState(() {
                    errorMessage = 'Minimum XP harus berupa angka'.tr(context);
                  });
                  return;
                }
                if (existing == null && xpParsed <= 0) {
                  setDialogState(() {
                    errorMessage =
                        'Minimum XP untuk rank baru harus lebih besar dari 0'
                            .tr(context);
                  });
                  return;
                }

                final minExp = isBaseRank ? 0 : xpParsed;
                final rank = RankModel(
                  id: existing?.id ?? '',
                  rankName: name,
                  minExp: minExp,
                  iconUrl: iconCtrl.text.trim(),
                );

                Navigator.pop(dialogCtx);

                final result = existing == null
                    ? await AdminApiService.createRank(widget.token, rank)
                    : await AdminApiService.updateRank(widget.token, rank);

                if (mounted) {
                  if (result.ok) {
                    _load();
                    _showSnack(
                      result.message ??
                          (existing == null
                              ? 'Rank berhasil ditambahkan'.tr(context)
                              : 'Rank berhasil diupdate'.tr(context)),
                      Colors.green,
                    );
                  } else {
                    _showSnack(
                      result.message ??
                          (existing == null
                              ? 'Gagal menambah rank'.tr(context)
                              : 'Gagal memperbarui rank'.tr(context)),
                      Colors.red,
                    );
                  }
                }
              },
              child: Text((existing == null ? 'Tambah' : 'Simpan').tr(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(RankModel rank) async {
    if (rank.minExp == 0) {
      _showSnack(
        'Rank dasar (min_exp = 0) tidak dapat dihapus.'.tr(context),
        Colors.red,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: Text(
          'Hapus Rank?'.tr(context),
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${"Hapus rank".tr(context)} "${rank.rankName}"? ${"Tindakan ini tidak bisa dibatalkan.".tr(context)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              'Relawan yang berada di rank ini akan otomatis di-downgrade ke rank di bawahnya.'
                  .tr(context),
              style: const TextStyle(color: Colors.amber, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal'.tr(context),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus'.tr(context)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await AdminApiService.deleteRank(widget.token, rank.id);
    if (mounted) {
      if (result.ok) {
        _load();
        _showSnack(
          result.message ?? 'Rank dihapus.'.tr(context),
          Colors.orange,
        );
      } else {
        _showSnack(
          result.message ?? 'Gagal menghapus rank'.tr(context),
          Colors.red,
        );
      }
    }
  }

  void _showSnack(String msg, Color color) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Relawan akan naik rank secara otomatis saat XP mereka mencapai batas minimum.'
                    .tr(context),
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7418),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text('Tambah Rank'.tr(context)),
              onPressed: () => _showForm(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _ranks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        size: 64,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada data rank. Silakan tambah rank baru.'.tr(
                          context,
                        ),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 160,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _ranks.length,
                  itemBuilder: (_, i) {
                    final r = _ranks[i];
                    return Card(
                      color: const Color(0xFF1A2035),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (r.iconUrl.startsWith('http'))
                                  Image.network(
                                    r.iconUrl,
                                    width: 28,
                                    height: 28,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.military_tech,
                                      size: 28,
                                      color: Color(0xFFFF7418),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.military_tech,
                                    size: 28,
                                    color: Color(0xFFFF7418),
                                  ),
                                if (r.minExp == 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1E88E5,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFF1E88E5),
                                      ),
                                    ),
                                    child: const Text(
                                      'BASE',
                                      style: TextStyle(
                                        color: Color(0xFF1E88E5),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                  onPressed: () => _showForm(existing: r),
                                  tooltip: 'Edit'.tr(context),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: r.minExp == 0
                                        ? Colors.white24
                                        : Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: r.minExp == 0
                                      ? null
                                      : () => _delete(r),
                                  tooltip: r.minExp == 0
                                      ? 'Rank dasar (min_exp = 0) tidak dapat dihapus.'
                                            .tr(context)
                                      : 'Hapus'.tr(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              r.rankName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Min. ${r.minExp} XP',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── TAB: BADGES ────────────────────────────────────────────────────────────

class _BadgesTab extends StatefulWidget {
  final String token;
  const _BadgesTab({required this.token});

  @override
  State<_BadgesTab> createState() => _BadgesTabState();
}

class _BadgesTabState extends State<_BadgesTab> {
  List<BadgeModel> _badges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminApiService.getBadges(widget.token);
    if (mounted) {
      setState(() {
        _badges = data;
        _loading = false;
      });
    }
  }

  Future<void> _showForm({BadgeModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.badgeName ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    List<int>? fileBytes;
    String? fileName;
    String currentIconUrl = existing?.iconUrl ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2537),
              title: Text(
                existing == null ? 'Tambah Badge Baru' : 'Edit Badge',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormField(
                      controller: nameCtrl,
                      label: 'Nama Badge',
                      hint: 'Contoh: Penyelamat Pertama',
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: descCtrl,
                      label: 'Deskripsi',
                      hint: 'Diberikan kepada relawan yang...',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ikon Badge',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (fileBytes != null)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image, color: Colors.green),
                          )
                        else if (currentIconUrl.isNotEmpty)
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: currentIconUrl.startsWith('http')
                                ? Image.network(
                                    currentIconUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.white38,
                                    ),
                                  )
                                : const Icon(
                                    Icons.image,
                                    color: Colors.white38,
                                  ),
                          )
                        else
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.white38,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            icon: const Icon(Icons.upload_file),
                            label: Text(
                              fileBytes != null
                                  ? (fileName ?? 'Ganti File')
                                  : 'Pilih Gambar',
                            ),
                            onPressed: () async {
                              final picked = await fp.FilePicker.pickFile(
                                type: fp.FileType.image,
                              );
                              if (picked != null) {
                                final bytes = await picked.readAsBytes();
                                setStateSB(() {
                                  fileBytes = bytes;
                                  fileName = picked.name;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7418),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(existing == null ? 'Tambah' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    bool ok;
    if (existing == null) {
      ok = await AdminApiService.createBadge(
        widget.token,
        nameCtrl.text,
        descCtrl.text,
        fileBytes,
        fileName,
      );
    } else {
      ok = await AdminApiService.updateBadge(
        widget.token,
        existing.id,
        nameCtrl.text,
        descCtrl.text,
        currentIconUrl,
        fileBytes,
        fileName,
      );
    }

    if (ok && mounted) {
      _load();
      _showSnack(
        existing == null
            ? 'Badge berhasil ditambahkan'
            : 'Badge berhasil diupdate',
        Colors.green,
      );
    }
  }

  Future<void> _delete(BadgeModel badge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text(
          'Hapus Badge?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Hapus badge "${badge.badgeName}"? Tindakan ini tidak bisa dibatalkan.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await AdminApiService.deleteBadge(widget.token, badge.id);
    if (ok && mounted) {
      _load();
      _showSnack('Badge dihapus.', Colors.orange);
    }
  }

  void _showSnack(String msg, Color color) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Badge diberikan secara manual oleh admin sebagai bentuk penghargaan khusus.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7418),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Badge'),
              onPressed: () => _showForm(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _badges.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.military_tech_outlined,
                        size: 64,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada data badge. Silakan tambah badge baru.',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 160,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _badges.length,
                  itemBuilder: (_, i) {
                    final b = _badges[i];
                    return Card(
                      color: const Color(0xFF1A2035),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (b.iconUrl.isNotEmpty &&
                                    b.iconUrl.startsWith('http'))
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      b.iconUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(
                                        Icons.broken_image,
                                        color: Colors.white38,
                                        size: 40,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.military_tech,
                                    color: Colors.white38,
                                    size: 40,
                                  ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                  onPressed: () => _showForm(existing: b),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () => _delete(b),
                                  tooltip: 'Hapus',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              b.badgeName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              b.description,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── SHARED WIDGET ──────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.numeric = false,
    this.enabled = true,
    this.helperText,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool numeric;
  final bool enabled;
  final String? helperText;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    style: TextStyle(color: enabled ? Colors.white : Colors.white38),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      helperStyle: const TextStyle(color: Colors.amber, fontSize: 12),
      helperMaxLines: 2,
      labelStyle: const TextStyle(color: Colors.white54),
      hintStyle: const TextStyle(color: Colors.white24),
      disabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white12),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white12),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFFF7418)),
      ),
    ),
  );
}
