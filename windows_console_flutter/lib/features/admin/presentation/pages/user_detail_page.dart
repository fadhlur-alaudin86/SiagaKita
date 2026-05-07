import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';

class UserDetailPage extends StatefulWidget {
  final String token;
  final String userId;
  const UserDetailPage({super.key, required this.token, required this.userId});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage>
    with SingleTickerProviderStateMixin {
  UserDetailModel? _detail;
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AdminApiService.getUserDetail(
        widget.token,
        widget.userId,
      );
      if (mounted) {
        setState(() {
          _detail = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Gagal memuat: $e', Colors.red);
      }
    }
  }

  void _snack(String msg, Color c) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));

  Future<void> _approveKyc() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text(
          'Setujui Verifikasi NIK?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Pastikan foto KTP dan selfie cocok.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Setujui', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await AdminApiService.approveWargaKyc(widget.token, widget.userId) &&
        mounted) {
      _snack('Verifikasi NIK disetujui', Colors.green);
      _load();
    }
  }

  Future<void> _rejectKyc() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text(
          'Tolak Verifikasi NIK?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Pengguna diminta upload ulang.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await AdminApiService.rejectWargaKyc(widget.token, widget.userId) &&
        mounted) {
      _snack('Verifikasi NIK ditolak', Colors.orange);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF111625),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_detail == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF111625),
        body: Center(
          child: Text(
            'Data tidak ditemukan',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final d = _detail!;
    final isBanned = d.isSosBanned;

    return Scaffold(
      backgroundColor: const Color(0xFF111625),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2035),
        elevation: 0,
        title: Text(
          'Detail: ${d.fullName ?? d.email}',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: (isBanned ? Colors.red : Colors.green).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isBanned ? Colors.red : Colors.green),
            ),
            child: Text(
              isBanned ? 'BANNED' : 'AKTIF',
              style: TextStyle(
                color: isBanned ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profil & Biodata ─────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto Profil
                _PhotoBox(
                  url: d.profilePhotoUrl,
                  size: 110,
                  placeholder: Icons.person,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              'Nama Lengkap',
                              d.fullName,
                              icon: Icons.badge,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoCard(
                              'Email',
                              d.email,
                              icon: Icons.email,
                              verified: d.isEmailVerified,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoCard(
                              'No. HP',
                              d.phoneNumber,
                              icon: Icons.phone,
                              verified: d.isPhoneVerified,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoCard(
                              'NIK',
                              d.nik,
                              icon: Icons.credit_card,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Data Medis ────────────────────────────────────────────────────
            const Text(
              'Data Medis & Darurat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _InfoCard('Tgl. Lahir', d.dateOfBirth)),
                const SizedBox(width: 10),
                Expanded(child: _InfoCard('Gol. Darah', d.bloodType)),
                const SizedBox(width: 10),
                Expanded(child: _InfoCard('Alergi', d.allergies)),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoCard(
                    'SOS Strike',
                    '${d.sosStrikeCount}/3',
                    icon: Icons.warning_amber_rounded,
                    iconColor: d.sosStrikeCount >= 3
                        ? Colors.red
                        : d.sosStrikeCount >= 2
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InfoCard('Alamat', d.alamat, icon: Icons.location_on),
            const SizedBox(height: 24),

            // ── Dokumen KTP ───────────────────────────────────────────────────
            const Text(
              'Dokumen Identitas (KTP)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoBox(
                  url: d.kycKtpUrl,
                  size: 200,
                  width: 320,
                  placeholder: Icons.credit_card,
                  emptyLabel: 'KTP Belum Diunggah',
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2035),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Verifikasi NIK',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              d.nikVerificationStatus == 'approved'
                                  ? Icons.check_circle
                                  : d.nikVerificationStatus == 'pending'
                                  ? Icons.access_time_filled
                                  : d.nikVerificationStatus == 'rejected'
                                  ? Icons.cancel
                                  : Icons.error_outline,
                              color: d.nikVerificationStatus == 'approved'
                                  ? Colors.blue
                                  : d.nikVerificationStatus == 'pending'
                                  ? Colors.orange
                                  : d.nikVerificationStatus == 'rejected'
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              d.nikVerificationStatus.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (d.nikVerificationStatus == 'pending' &&
                            d.kycKtpUrl != null) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text(
                                  'Setujui',
                                  style: TextStyle(color: Colors.white),
                                ),
                                onPressed: _approveKyc,
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Tolak'),
                                onPressed: _rejectKyc,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Riwayat (Tab) ─────────────────────────────────────────────────
            const Text(
              'Riwayat Aktivitas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A2035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabCtrl,
                    labelColor: const Color(0xFFFF7418),
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: const Color(0xFFFF7418),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(text: 'SOS (${d.sosHistory.length})'),
                      Tab(text: 'Laporan (${d.reportHistory.length})'),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // SOS History
                        d.sosHistory.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada riwayat SOS.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: d.sosHistory.length,
                                separatorBuilder: (_, _) => const Divider(
                                  color: Colors.white10,
                                  height: 1,
                                ),
                                itemBuilder: (_, i) {
                                  final h = d.sosHistory[i];
                                  final isFalse = h.status == 'false_alarm';
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          (isFalse
                                                  ? Colors.orange
                                                  : Colors.blue)
                                              .withValues(alpha: .15),
                                      child: Icon(
                                        isFalse
                                            ? Icons.warning_amber
                                            : Icons.emergency,
                                        color: isFalse
                                            ? Colors.orange
                                            : Colors.blue,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      _incidentLabel(h.incidentType),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy, HH:mm',
                                          ).format(h.createdAt.toLocal()),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (h.resolvedAt != null)
                                          Text(
                                            'Selesai: ${DateFormat('dd MMM yyyy, HH:mm').format(h.resolvedAt!.toLocal())}',
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 10,
                                            ),
                                          ),
                                        Text(
                                          '${h.latitude.toStringAsFixed(5)}, ${h.longitude.toStringAsFixed(5)}',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: _StatusBadge(h.status),
                                  );
                                },
                              ),
                        // Report History
                        d.reportHistory.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada riwayat laporan.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: d.reportHistory.length,
                                separatorBuilder: (_, _) => const Divider(
                                  color: Colors.white10,
                                  height: 1,
                                ),
                                itemBuilder: (_, i) {
                                  final r = d.reportHistory[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.purple.withValues(
                                        alpha: 0.15,
                                      ),
                                      child: const Icon(
                                        Icons.report,
                                        color: Colors.purple,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      _incidentLabel(r.incidentType),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy, HH:mm',
                                          ).format(r.createdAt.toLocal()),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (r.description != null)
                                          Text(
                                            r.description!,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 11,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    trailing: _StatusBadge(r.status),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _incidentLabel(String type) => switch (type) {
    'fire' => '🔥 Kebakaran',
    'medical' => '🚑 Medis',
    'crime' => '🔪 Kriminal',
    'rescue' => '💥 Kecelakaan',
    'general' => '📋 Umum',
    _ => type.toUpperCase(),
  };
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard(
    this.label,
    this.value, {
    this.icon,
    this.iconColor,
    this.verified,
  });
  final String label;
  final String? value;
  final IconData? icon;
  final Color? iconColor;
  final bool? verified;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1E2537),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor ?? Colors.white38, size: 18),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  if (verified != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      verified! ? Icons.check_circle : Icons.error_outline,
                      size: 11,
                      color: verified! ? Colors.blue : Colors.orange,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                value ?? '-',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.url,
    required this.size,
    required this.placeholder,
    this.width,
    this.emptyLabel,
  });
  final String? url;
  final double size;
  final double? width;
  final IconData placeholder;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) => Container(
    width: width ?? size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF1E2537),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white10),
      image: url != null
          ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
          : null,
    ),
    child: url == null
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(placeholder, size: 48, color: Colors.white24),
              if (emptyLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  emptyLabel!,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          )
        : null,
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => Colors.green,
      'false_alarm' => Colors.orange,
      'broadcasting' || 'active' => Colors.blue,
      'pending' => Colors.yellow,
      'reviewed' => Colors.teal,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
