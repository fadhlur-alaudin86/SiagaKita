import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
import '../../../../core/localization/app_localization.dart';
import 'user_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
class UserManagementPage extends StatelessWidget {
  final String token;
  final String role;
  const UserManagementPage({
    super.key,
    required this.token,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      Tab(text: 'Masyarakat'.tr(context)),
      Tab(text: 'Relawan'.tr(context)),
      Tab(text: 'Instansi'.tr(context)),
      if (role == 'superadmin') Tab(text: 'Admin'.tr(context)),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: const Color(0xFFFF7418),
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFFFF7418),
            tabs: tabs,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _UserListTab(
                  token: token,
                  roleFilter: 'civilian',
                  label: 'masyarakat',
                ),
                _UserListTab(
                  token: token,
                  roleFilter: 'volunteer',
                  label: 'relawan',
                ),
                _InstansiTabView(token: token),
                if (role == 'superadmin') _AdminTabView(token: token),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Enum helpers ────────────────────────────────────────────────────────────
enum _BanFilter { all, banned, active }

enum _OnlineFilter { all, online, background, offline }

enum _SortBy { name, nik, strike, status }

enum _SortDir { asc, desc }

// ─── Shared user list tab (civilian + volunteer) ──────────────────────────────
class _UserListTab extends StatefulWidget {
  final String token;
  final String roleFilter;
  final String label;
  const _UserListTab({
    required this.token,
    required this.roleFilter,
    required this.label,
  });

  @override
  State<_UserListTab> createState() => _UserListTabState();
}

class _UserListTabState extends State<_UserListTab> {
  List<UserModel> _all = [];
  List<UserModel> _view = [];
  bool _loading = true;
  String _search = '';
  _BanFilter _banFilter = _BanFilter.all;
  _OnlineFilter _onlineFilter = _OnlineFilter.all;
  int _minStrike = 0;
  _SortBy _sortBy = _SortBy.name;
  _SortDir _sortDir = _SortDir.asc;
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
      final data = await AdminApiService.getUsers(
        widget.token,
        role: widget.roleFilter,
      );
      if (mounted) {
        setState(() {
          _all = data;
          _applyFilterSort();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('${'Gagal memuat data'.tr(context)}: $e', Colors.red);
      }
    }
  }

  String _onlineCategory(UserModel u) {
    if (u.isSOSBanned) return 'banned';
    final s = u.onlineStatus;
    if (s == 'Online') return 'online';
    if (s.contains('latar belakang')) return 'background';
    return 'offline';
  }

  void _applyFilterSort() {
    var list = _all.where((u) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!u.fullName.toLowerCase().contains(q) &&
            !u.email.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_banFilter == _BanFilter.banned && !u.isSOSBanned) return false;
      if (_banFilter == _BanFilter.active && u.isSOSBanned) return false;
      final cat = _onlineCategory(u);
      if (_onlineFilter == _OnlineFilter.online && cat != 'online') {
        return false;
      }
      if (_onlineFilter == _OnlineFilter.background && cat != 'background') {
        return false;
      }
      if (_onlineFilter == _OnlineFilter.offline && cat != 'offline') {
        return false;
      }
      if (u.sosStrikeCount < _minStrike) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case _SortBy.name:
          cmp = a.fullName.compareTo(b.fullName);
        case _SortBy.nik:
          cmp = (a.nik ?? '').compareTo(b.nik ?? '');
        case _SortBy.strike:
          cmp = a.sosStrikeCount.compareTo(b.sosStrikeCount);
        case _SortBy.status:
          const order = {
            'online': 0,
            'background': 1,
            'offline': 2,
            'banned': 3,
          };
          cmp = (order[_onlineCategory(a)] ?? 2).compareTo(
            order[_onlineCategory(b)] ?? 2,
          );
      }
      return _sortDir == _SortDir.asc ? cmp : -cmp;
    });
    _view = list;
  }

  void _setFilter(VoidCallback fn) => setState(() {
    fn();
    _applyFilterSort();
  });

  Future<void> _ban(UserModel user) async {
    _banReasonCtrl.clear();
    int selectedDays = 7;
    final durations = [
      (1, '1 Hari'),
      (3, '3 Hari'),
      (7, '7 Hari'),
      (30, '30 Hari'),
      (365, 'Permanen (365 Hari)'),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, ss) => AlertDialog(
          backgroundColor: const Color(0xFF1E2537),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.block, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${'Ban'.tr(context)} ${user.fullName}?',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengguna tidak bisa menggunakan SOS.'.tr(context),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  'Durasi Ban'.tr(context),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: durations.map((d) {
                    final isSel = selectedDays == d.$1;
                    return ChoiceChip(
                      label: Text(d.$2.tr(context)),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) ss(() => selectedDays = d.$1);
                      },
                      selectedColor: Colors.red.withValues(alpha: 0.3),
                      backgroundColor: const Color(0xFF1A2035),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.white60,
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSel ? Colors.red : Colors.white12,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _banReasonCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (_) => ss(() {}),
                  decoration: InputDecoration(
                    labelText: 'Alasan ban'.tr(context),
                    hintText: 'Contoh: Panggilan palsu berulang kali',
                    labelStyle: const TextStyle(color: Colors.white54),
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _banReasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text('Ban'.tr(context)),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (ok != true) return;
    final reason = _banReasonCtrl.text.trim();
    if (reason.isEmpty) {
      _snack('Alasan ban wajib diisi'.tr(context), Colors.orange);
      return;
    }

    final result = await AdminApiService.banUser(
      widget.token,
      user.id,
      reason,
      selectedDays,
    );
    if (!mounted) return;
    if (result.ok) {
      _load();
      final msg =
          result.message ?? '${user.fullName} ${'telah dibanned.'.tr(context)}';
      _snack(msg, Colors.red);
    } else {
      final errorMsg = result.message ?? 'Gagal melakukan ban.'.tr(context);
      _snack(errorMsg, Colors.red);
    }
  }

  Future<void> _unban(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_outlined, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${'Unban'.tr(context)} ${user.fullName}?',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Pengguna dapat menggunakan SOS kembali.'.tr(context),
          style: const TextStyle(color: Colors.white70),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unban'.tr(context)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    final result = await AdminApiService.unbanUser(widget.token, user.id);
    if (!mounted) return;
    if (result.ok) {
      _load();
      final msg =
          result.message ?? '${user.fullName} ${'di-unban.'.tr(context)}';
      _snack(msg, Colors.green);
    } else {
      final errorMsg = result.message ?? 'Gagal mencabut ban.'.tr(context);
      _snack(errorMsg, Colors.red);
    }
  }

  Future<void> _resetStrike(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.refresh, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Konfirmasi Reset Strike'.tr(context),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'Apakah Anda yakin ingin mereset strike untuk'.tr(context)} ${user.fullName}?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${'Strike'.tr(context)}: ${user.sosStrikeCount}/3',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tindakan ini akan mengembalikan strike ke 0/3.'.tr(context),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reset Strike'.tr(context)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    final result = await AdminApiService.resetStrike(widget.token, user.id);
    if (!mounted) return;
    if (result.ok) {
      _load();
      final msg = result.message ?? 'Strike berhasil direset.'.tr(context);
      _snack(msg, Colors.blue);
    } else {
      final errorMsg = result.message ?? 'Gagal mereset strike.'.tr(context);
      _snack(errorMsg, Colors.red);
    }
  }

  void _snack(String msg, Color c) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter & Sort Bar ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                onChanged: (v) => _setFilter(() => _search = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email...'.tr(context),
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
            const SizedBox(width: 10),
            // Ban filter
            _DropdownFilter<_BanFilter>(
              label: 'Status Akun'.tr(context),
              value: _banFilter,
              items: {
                _BanFilter.all: 'Semua'.tr(context),
                _BanFilter.active: 'Aktif'.tr(context),
                _BanFilter.banned: 'Banned'.tr(context),
              },
              onChanged: (v) => _setFilter(() => _banFilter = v),
            ),
            const SizedBox(width: 8),
            // Online filter
            _DropdownFilter<_OnlineFilter>(
              label: 'Koneksi'.tr(context),
              value: _onlineFilter,
              items: {
                _OnlineFilter.all: 'Semua'.tr(context),
                _OnlineFilter.online: 'Online'.tr(context),
                _OnlineFilter.background: 'Latar Belakang'.tr(context),
                _OnlineFilter.offline: 'Offline'.tr(context),
              },
              onChanged: (v) => _setFilter(() => _onlineFilter = v),
            ),
            const SizedBox(width: 8),
            // Strike filter
            _StrikeFilterBtn(
              value: _minStrike,
              onChanged: (v) => _setFilter(() => _minStrike = v),
            ),
            const SizedBox(width: 8),
            // Sort
            _DropdownFilter<_SortBy>(
              label: 'Urutkan'.tr(context),
              icon: Icons.sort,
              value: _sortBy,
              items: {
                _SortBy.name: 'Nama'.tr(context),
                _SortBy.nik: 'NIK'.tr(context),
                _SortBy.strike: 'Strike'.tr(context),
                _SortBy.status: 'Status'.tr(context),
              },
              onChanged: (v) => _setFilter(() => _sortBy = v),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: _sortDir == _SortDir.asc
                  ? 'Naik'.tr(context)
                  : 'Turun'.tr(context),
              icon: Icon(
                _sortDir == _SortDir.asc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: const Color(0xFFFF7418),
                size: 18,
              ),
              onPressed: () => _setFilter(
                () => _sortDir = _sortDir == _SortDir.asc
                    ? _SortDir.desc
                    : _SortDir.asc,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

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
                          vertical: 10,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 28,
                              child: _TH('NAMA & STATUS'.tr(context)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(flex: 18, child: _TH('NIK'.tr(context))),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 28,
                              child: _TH('KONTAK'.tr(context)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 10,
                              child: _TH('STRIKE'.tr(context)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(flex: 28, child: _TH('AKSI'.tr(context))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _view.isEmpty
                            ? Center(
                                child: Text(
                                  'Tidak ada data'.tr(context),
                                  style: const TextStyle(color: Colors.white38),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _view.length,
                                separatorBuilder: (_, _) => const Divider(
                                  color: Colors.white10,
                                  height: 1,
                                ),
                                itemBuilder: (ctx, i) {
                                  final u = _view[i];
                                  return _UserRow(
                                    user: u,
                                    token: widget.token,
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

// ─── User Row ─────────────────────────────────────────────────────────────────
class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.token,
    required this.onBan,
    required this.onUnban,
    required this.onResetStrike,
  });
  final UserModel user;
  final String token;
  final VoidCallback onBan, onUnban, onResetStrike;

  @override
  Widget build(BuildContext context) {
    final strikeColor = user.sosStrikeCount >= 3
        ? const Color(0xFFE53935)
        : user.sosStrikeCount == 2
        ? const Color(0xFFFFB300)
        : const Color(0xFF43A047);
    final isBanned = user.isSOSBanned;
    final statusLabel = isBanned ? 'BANNED' : user.onlineStatus;
    final statusColor = isBanned
        ? Colors.red
        : user.onlineStatus == 'Online'
        ? Colors.green
        : user.onlineStatus.contains('latar belakang')
        ? Colors.orange
        : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NAMA & STATUS
          Expanded(
            flex: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // NIK
          Expanded(
            flex: 18,
            child: Row(
              children: [
                Icon(
                  user.nikVerificationStatus == 'approved'
                      ? Icons.check_circle
                      : user.nikVerificationStatus == 'pending'
                      ? Icons.access_time_filled
                      : user.nikVerificationStatus == 'rejected'
                      ? Icons.cancel
                      : Icons.error_outline,
                  color: user.nikVerificationStatus == 'approved'
                      ? Colors.blue
                      : user.nikVerificationStatus == 'pending'
                      ? Colors.orange
                      : user.nikVerificationStatus == 'rejected'
                      ? Colors.red
                      : Colors.grey,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    user.nik ?? '-',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // KONTAK
          Expanded(
            flex: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      user.isEmailVerified
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: user.isEmailVerified ? Colors.blue : Colors.orange,
                      size: 11,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      user.isPhoneVerified
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: user.isPhoneVerified ? Colors.blue : Colors.orange,
                      size: 11,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        user.phoneNumber ?? '-',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // STRIKE
          Expanded(
            flex: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: strikeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: strikeColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: strikeColor,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${user.sosStrikeCount}/3',
                    style: TextStyle(
                      color: strikeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // AKSI
          Expanded(
            flex: 28,
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _ActionBtn(
                  label: 'Detail'.tr(context),
                  color: Colors.purpleAccent,
                  icon: Icons.remove_red_eye,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UserDetailPage(token: token, userId: user.id),
                    ),
                  ),
                ),
                if (isBanned)
                  _ActionBtn(
                    label: 'Unban'.tr(context),
                    color: Colors.green,
                    icon: Icons.lock_open_outlined,
                    onTap: onUnban,
                  )
                else
                  _ActionBtn(
                    label: 'Ban'.tr(context),
                    color: Colors.red,
                    icon: Icons.block,
                    onTap: onBan,
                  ),
                if (user.sosStrikeCount > 0)
                  _ActionBtn(
                    label: 'Reset'.tr(context),
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

// ─── INSTANSI TAB ─────────────────────────────────────────────────────────────
class _InstansiTabView extends StatefulWidget {
  final String token;
  const _InstansiTabView({required this.token});
  @override
  State<_InstansiTabView> createState() => _InstansiTabViewState();
}

class _InstansiTabViewState extends State<_InstansiTabView> {
  List<AgencyModel> _agencies = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AdminApiService.getAgencies(widget.token);
      if (mounted) {
        setState(() {
          _agencies = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_agencies.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada instansi.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _agencies.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = _agencies[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      a.typeLabel,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  a.email,
                  style: const TextStyle(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  a.cityCode,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              Expanded(
                child: Text(
                  a.hotlineNumber ?? '-',
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── ADMIN TAB ────────────────────────────────────────────────────────────────
class _AdminTabView extends StatefulWidget {
  final String token;
  const _AdminTabView({required this.token});
  @override
  State<_AdminTabView> createState() => _AdminTabViewState();
}

class _AdminTabViewState extends State<_AdminTabView> {
  List<AdminModel> _admins = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AdminApiService.getAdmins(widget.token);
      if (mounted) {
        setState(() {
          _admins = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_admins.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada admin.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _admins.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = _admins[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  a.fullName ?? '-',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  a.email,
                  style: const TextStyle(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.role.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared Helper Widgets ────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  const _TH(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 10,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
    ),
  );
}

class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon,
  });
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final displayText = items[value] ?? label;
    return PopupMenuButton<T>(
      initialValue: value,
      color: const Color(0xFF1E2537),
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white12),
      ),
      onSelected: onChanged,
      itemBuilder: (ctx) => items.entries
          .map(
            (e) => PopupMenuItem<T>(
              value: e.key,
              child: Text(
                e.value,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayText,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(icon ?? Icons.filter_list, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StrikeFilterBtn extends StatelessWidget {
  const _StrikeFilterBtn({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == 0
        ? 'Semua Strike'.tr(context)
        : '${'Strike'.tr(context)} ≥ $value';
    return PopupMenuButton<int>(
      initialValue: value,
      color: const Color(0xFF1E2537),
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: value > 0
              ? Colors.orange.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      onSelected: onChanged,
      itemBuilder: (ctx) => [0, 1, 2, 3]
          .map(
            (v) => PopupMenuItem<int>(
              value: v,
              child: Text(
                v == 0
                    ? 'Semua Strike'.tr(context)
                    : '${'Strike'.tr(context)} ≥ $v',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value > 0 ? Colors.orange : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.warning_amber_rounded,
              color: value > 0 ? Colors.orange : Colors.white38,
              size: 16,
            ),
          ],
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
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 11),
            const SizedBox(width: 3),
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
