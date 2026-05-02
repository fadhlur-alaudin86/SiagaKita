import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';

class GamifikasiPage extends StatefulWidget {
  final String token;
  const GamifikasiPage({super.key, required this.token});

  @override
  State<GamifikasiPage> createState() => _GamifikasiPageState();
}

class _GamifikasiPageState extends State<GamifikasiPage> {
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
    final nameCtrl = TextEditingController(text: existing?.rankName ?? '');
    final xpCtrl = TextEditingController(
      text: existing?.minExp.toString() ?? '0',
    );
    final iconCtrl = TextEditingController(text: existing?.iconUrl ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: Text(
          existing == null ? 'Tambah Rank Baru' : 'Edit Rank',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FormField(
                controller: nameCtrl,
                label: 'Nama Rank',
                hint: 'Contoh: Relawan Ahli',
              ),
              const SizedBox(height: 12),
              _FormField(
                controller: xpCtrl,
                label: 'Minimum XP',
                hint: '1000',
                numeric: true,
              ),
              const SizedBox(height: 12),
              _FormField(
                controller: iconCtrl,
                label: 'Icon URL / Emoji',
                hint: '🏅 atau URL gambar',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7418),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(existing == null ? 'Tambah' : 'Simpan'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final rank = RankModel(
      id: existing?.id ?? '',
      rankName: nameCtrl.text,
      minExp: int.tryParse(xpCtrl.text) ?? 0,
      iconUrl: iconCtrl.text,
    );

    bool ok;
    if (existing == null) {
      ok = await AdminApiService.createRank(widget.token, rank);
    } else {
      ok = await AdminApiService.updateRank(widget.token, rank);
    }

    if (ok && mounted) {
      _load();
      _showSnack(
        existing == null
            ? 'Rank berhasil ditambahkan'
            : 'Rank berhasil diupdate',
        Colors.green,
      );
    }
  }

  Future<void> _delete(RankModel rank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text('Hapus Rank?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Hapus rank "${rank.rankName}"? Tindakan ini tidak bisa dibatalkan.',
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
    final ok = await AdminApiService.deleteRank(widget.token, rank.id);
    if (ok && mounted) {
      _load();
      _showSnack('Rank dihapus.', Colors.orange);
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
            const Text(
              'Master Data Rank Relawan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7418),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Rank'),
              onPressed: () => _showForm(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Relawan akan naik rank secara otomatis saat XP mereka mencapai batas minimum.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
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
                      const Text(
                        'Belum ada data rank. Silakan tambah rank baru.',
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
                                Text(
                                  r.iconUrl.length <= 4 ? r.iconUrl : '🏅',
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                  onPressed: () => _showForm(existing: r),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () => _delete(r),
                                  tooltip: 'Hapus',
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

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.numeric = false,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool numeric;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white54),
      hintStyle: const TextStyle(color: Colors.white24),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white12),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFFF7418)),
      ),
    ),
  );
}
