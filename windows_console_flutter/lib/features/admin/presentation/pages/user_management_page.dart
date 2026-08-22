import 'package:flutter/material.dart';
import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';
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
      const Tab(text: 'Masyarakat'),
      const Tab(text: 'Relawan'),
      const Tab(text: 'Instansi'),
      if (role == 'superadmin') const Tab(text: 'Admin'),
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
      final data = await AdminApiService.getUsers(widget.token);
      if (mounted) {
        setState(() {
          _all = data.where((u) => u.role == widget.roleFilter).toList();
          _applyFilterSort();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Gagal memuat data: $e', Colors.red);
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
    final daysCtrl = TextEditingController(text: '7');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, ss) => AlertDialog(
          backgroundColor: const Color(0xFF1E2537),
          title: Text(
            'Ban ${user.fullName}?',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pengguna tidak bisa menggunakan SOS.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _inputField(
                _banReasonCtrl,
                'Alasan ban',
                onChanged: (_) => ss(() {}),
              ),
              const SizedBox(height: 8),
              _inputField(daysCtrl, 'Durasi (hari)', isNum: true),
            ],
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _banReasonCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Ban', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || _banReasonCtrl.text.trim().isEmpty) return;
    final days = int.tryParse(daysCtrl.text) ?? 7;
    if (await AdminApiService.banUser(
          widget.token,
          user.id,
          _banReasonCtrl.text,
          days,
        ) &&
        mounted) {
      _load();
      _snack('${user.fullName} telah dibanned.', Colors.red);
    }
  }

  Future<void> _unban(UserModel user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: Text(
          'Unban ${user.fullName}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Pengguna dapat menggunakan SOS kembali.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unban', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await AdminApiService.unbanUser(widget.token, user.id) && mounted) {
      _load();
      _snack('${user.fullName} di-unban.', Colors.green);
    }
  }

  Future<void> _resetStrike(UserModel user) async {
    if (await AdminApiService.resetStrike(widget.token, user.id) && mounted) {
      _load();
      _snack('Strike ${user.fullName} direset.', Colors.blue);
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
            const SizedBox(width: 10),
            // Ban filter
            _DropdownFilter<_BanFilter>(
              label: 'Status Akun',
              value: _banFilter,
              items: const {
                _BanFilter.all: 'Semua',
                _BanFilter.active: 'Aktif',
                _BanFilter.banned: 'Banned',
              },
              onChanged: (v) => _setFilter(() => _banFilter = v),
            ),
            const SizedBox(width: 8),
            // Online filter
            _DropdownFilter<_OnlineFilter>(
              label: 'Koneksi',
              value: _onlineFilter,
              items: const {
                _OnlineFilter.all: 'Semua',
                _OnlineFilter.online: 'Online',
                _OnlineFilter.background: 'Latar Belakang',
                _OnlineFilter.offline: 'Offline',
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
              label: 'Urutkan',
              icon: Icons.sort,
              value: _sortBy,
              items: const {
                _SortBy.name: 'Nama',
                _SortBy.nik: 'NIK',
                _SortBy.strike: 'Strike',
                _SortBy.status: 'Status',
              },
              onChanged: (v) => _setFilter(() => _sortBy = v),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: _sortDir == _SortDir.asc ? 'Naik' : 'Turun',
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
                        child: const Row(
                          children: [
                            Expanded(flex: 28, child: _TH('NAMA & STATUS')),
                            SizedBox(width: 8),
                            Expanded(flex: 18, child: _TH('NIK')),
                            SizedBox(width: 8),
                            Expanded(flex: 28, child: _TH('KONTAK')),
                            SizedBox(width: 8),
                            Expanded(flex: 10, child: _TH('STRIKE')),
                            SizedBox(width: 8),
                            Expanded(flex: 28, child: _TH('AKSI')),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _view.isEmpty
                            ? const Center(
                                child: Text(
                                  'Tidak ada data',
                                  style: TextStyle(color: Colors.white38),
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
        ? Colors.red
        : user.sosStrikeCount >= 2
        ? Colors.orange
        : Colors.green;
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
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: strikeColor, size: 13),
                const SizedBox(width: 3),
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
          const SizedBox(width: 8),
          // AKSI
          Expanded(
            flex: 28,
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _ActionBtn(
                  label: 'Detail',
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
    final label = value == 0 ? 'Semua Strike' : 'Strike ≥ $value';
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
                v == 0 ? 'Semua Strike' : 'Strike ≥ $v',
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

TextField _inputField(
  TextEditingController ctrl,
  String label, {
  bool isNum = false,
  void Function(String)? onChanged,
}) => TextField(
  controller: ctrl,
  keyboardType: isNum ? TextInputType.number : TextInputType.text,
  onChanged: onChanged,
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white54),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.white24),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFFF7418)),
    ),
  ),
);
