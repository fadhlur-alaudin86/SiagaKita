import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';

class UserManagementPage extends StatefulWidget {
  final String token;
  const UserManagementPage({super.key, required this.token});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<UserModel> _all = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  String _filterType = 'all'; // 'all' | 'banned' | 'strike'
  String _search = '';
  final _banReasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _banReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AdminApiService.getUsers(widget.token);
      if (mounted) {
        setState(() {
          _all = data;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Gagal memuat pengguna: $e', Colors.red);
      }
    }
  }

  void _applyFilter() {
    _filtered = _all.where((u) {
      final matchSearch =
          _search.isEmpty ||
          u.fullName.toLowerCase().contains(_search.toLowerCase()) ||
          u.email.toLowerCase().contains(_search.toLowerCase());
      final matchFilter = switch (_filterType) {
        'banned' => u.isSOSBanned,
        'strike' => u.sosStrikeCount >= 2,
        _ => true,
      };
      return matchSearch && matchFilter;
    }).toList();
  }

  Future<void> _ban(UserModel user) async {
    _banReasonCtrl.clear();
    final banDaysCtrl = TextEditingController(text: '7');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E2537),
            title: Text(
              'Ban ${user.fullName}?',
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengguna tidak akan bisa menggunakan fitur SOS.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _banReasonCtrl,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (v) => setStateBuilder(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Alasan ban',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: banDaysCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Rentang waktu ban (hari)',
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7418)),
                onPressed: _banReasonCtrl.text.trim().isEmpty ? null : () => Navigator.pop(ctx, true),
                child: const Text('Ban Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
    if (confirmed != true || _banReasonCtrl.text.trim().isEmpty) return;
    int days = int.tryParse(banDaysCtrl.text) ?? 7;
    final ok = await AdminApiService.banUser(
      widget.token,
      user.id,
      _banReasonCtrl.text,
      days,
    );
    if (ok && mounted) {
      _load();
      _showSnack('${user.fullName} telah dibanned.', Colors.red);
    }
  }

  Future<void> _unban(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: Text(
          'Unban ${user.fullName}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Pengguna akan bisa menggunakan fitur SOS kembali.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unban Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await AdminApiService.unbanUser(widget.token, user.id);
    if (ok && mounted) {
      _load();
      _showSnack('${user.fullName} telah di-unban.', Colors.green);
    }
  }

  Future<void> _resetStrike(UserModel user) async {
    final ok = await AdminApiService.resetStrike(widget.token, user.id);
    if (ok && mounted) {
      _load();
      _showSnack('Strike ${user.fullName} telah direset.', Colors.blue);
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
        // ── Filter bar ────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() {
                  _search = v;
                  _applyFilter();
                }),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A2035),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _FilterChip(
              label: 'Semua',
              selected: _filterType == 'all',
              onTap: () => setState(() {
                _filterType = 'all';
                _applyFilter();
              }),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '⚠️ Strike ≥ 2',
              selected: _filterType == 'strike',
              color: Colors.orange,
              onTap: () => setState(() {
                _filterType = 'strike';
                _applyFilter();
              }),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: '🚫 Banned',
              selected: _filterType == 'banned',
              color: Colors.red,
              onTap: () => setState(() {
                _filterType = 'banned';
                _applyFilter();
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Table ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Card(
                  color: const Color(0xFF1A2035),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: _TableHeader('NAMA')),
                            Expanded(flex: 3, child: _TableHeader('EMAIL')),
                            Expanded(flex: 2, child: _TableHeader('HP')),
                            Expanded(child: _TableHeader('STRIKE')),
                            Expanded(flex: 2, child: _TableHeader('STATUS')),
                            Expanded(flex: 3, child: _TableHeader('AKSI')),
                          ],
                        ),
                      ),
                      // Rows
                      Expanded(
                        child: _filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tidak ada pengguna ditemukan',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _filtered.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(color: Colors.white10, height: 1),
                                itemBuilder: (context, i) {
                                  final u = _filtered[i];
                                  return _UserRow(
                                    user: u,
                                    onBan: () => _ban(u),
                                    onUnban: () => _unban(u),
                                    onResetStrike: () => _resetStrike(u),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.onBan,
    required this.onUnban,
    required this.onResetStrike,
  });

  final UserModel user;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onResetStrike;

  @override
  Widget build(BuildContext context) {
    final strikeColor = user.sosStrikeCount >= 3
        ? Colors.red
        : user.sosStrikeCount >= 2
        ? Colors.orange
        : Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              user.fullName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              user.email,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user.phoneNumber ?? '-',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: strikeColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${user.sosStrikeCount}/3',
                  style: TextStyle(
                    color: strikeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isSOSBanned
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  user.isSOSBanned ? '🚫 BANNED' : '✅ Aktif',
                  style: TextStyle(
                    color: user.isSOSBanned ? Colors.red : Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              children: [
                if (user.isSOSBanned)
                  _ActionBtn(
                    label: 'Unban',
                    color: Colors.green,
                    icon: Icons.lock_open_outlined,
                    onTap: onUnban,
                  )
                else
                  _ActionBtn(
                    label: 'Ban',
                    color: Colors.red,
                    icon: Icons.block,
                    onTap: onBan,
                  ),
                if (user.sosStrikeCount > 0)
                  _ActionBtn(
                    label: 'Reset',
                    color: Colors.blue,
                    icon: Icons.refresh,
                    onTap: onResetStrike,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFFFF7418);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.2) : const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? c : Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c : Colors.white54,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
