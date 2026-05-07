import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';

class UserDetailPage extends StatefulWidget {
  final String token;
  final String userId;

  const UserDetailPage({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  UserDetailModel? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await AdminApiService.getUserDetail(widget.token, widget.userId);
      if (mounted) {
        setState(() {
          _detail = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Gagal memuat detail pengguna: $e', Colors.red);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Widget _buildInfoCard(String title, String? value, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2537),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? '-',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

  Future<void> _handleKycApprove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text('Setujui Verifikasi NIK?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Pastikan foto KTP dan wajah sesuai dengan data.',
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
    if (confirmed != true) return;

    final ok = await AdminApiService.approveWargaKyc(widget.token, widget.userId);
    if (ok && mounted) {
      _showSnack('Verifikasi NIK disetujui', Colors.green);
      _load();
    }
  }

  Future<void> _handleKycReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text('Tolak Verifikasi NIK?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Pengguna akan diminta mengupload ulang data KYC.',
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
    if (confirmed != true) return;

    final ok = await AdminApiService.rejectWargaKyc(widget.token, widget.userId);
    if (ok && mounted) {
      _showSnack('Verifikasi NIK ditolak', Colors.orange);
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
        body: Center(child: Text('Data tidak ditemukan', style: TextStyle(color: Colors.white))),
      );
    }

    final detail = _detail!;

    return Scaffold(
      backgroundColor: const Color(0xFF111625),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2035),
        title: Text(
          'Detail Pengguna: ${detail.fullName ?? detail.email}',
          style: const TextStyle(fontSize: 16),
        ),
        elevation: 0,
        actions: [
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: detail.isSosBanned ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: detail.isSosBanned ? Colors.red : Colors.green,
              ),
            ),
            child: Text(
              detail.isSosBanned ? 'BANNED' : 'AKTIF',
              style: TextStyle(
                color: detail.isSosBanned ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Baris Atas: Profil Utama & Verifikasi ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto Profil
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2537),
                    borderRadius: BorderRadius.circular(16),
                    image: detail.profilePhotoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(detail.profilePhotoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: detail.profilePhotoUrl == null
                      ? const Icon(Icons.person, size: 64, color: Colors.white24)
                      : null,
                ),
                const SizedBox(width: 24),
                // Data Inti
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildInfoCard('Nama Lengkap', detail.fullName, icon: Icons.badge)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInfoCard('Email', detail.email, icon: Icons.email)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildInfoCard('No. HP', detail.phoneNumber, icon: Icons.phone)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              'NIK',
                              detail.nik,
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
            const SizedBox(height: 24),

            // ── Baris Tengah: Status Medis & Lainnya ──
            const Text('Data Medis & Darurat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInfoCard('Tanggal Lahir', detail.dateOfBirth)),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard('Gol. Darah', detail.bloodType)),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard('Alergi', detail.allergies)),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    'SOS Strike',
                    '${detail.sosStrikeCount}/3',
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoCard('Alamat', detail.alamat, icon: Icons.location_on),
            const SizedBox(height: 32),

            // ── Section: Foto KTP & Verifikasi KYC ──
            const Text('Dokumen Identitas (KTP)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 320,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2537),
                    borderRadius: BorderRadius.circular(16),
                    image: detail.kycKtpUrl != null
                        ? DecorationImage(
                            image: NetworkImage(detail.kycKtpUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: Border.all(color: Colors.white10),
                  ),
                  child: detail.kycKtpUrl == null
                      ? const Center(child: Text('KTP Belum Diunggah', style: TextStyle(color: Colors.white54)))
                      : null,
                ),
                const SizedBox(width: 24),
                // Status KYC & Aksi
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2035),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Status Verifikasi NIK', style: TextStyle(color: Colors.white54)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              detail.nikVerificationStatus == 'approved' ? Icons.check_circle :
                              detail.nikVerificationStatus == 'pending' ? Icons.access_time_filled :
                              detail.nikVerificationStatus == 'rejected' ? Icons.cancel : Icons.error_outline,
                              color: detail.nikVerificationStatus == 'approved' ? Colors.blue :
                                     detail.nikVerificationStatus == 'pending' ? Colors.orange :
                                     detail.nikVerificationStatus == 'rejected' ? Colors.red : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              detail.nikVerificationStatus.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (detail.nikVerificationStatus == 'pending' && detail.kycKtpUrl != null) ...[
                          const Text('Aksi Verifikasi', style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text('Setujui KTP', style: TextStyle(color: Colors.white)),
                                onPressed: _handleKycApprove,
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('Tolak Data'),
                                onPressed: _handleKycReject,
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Section: Riwayat SOS & Laporan ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Riwayat SOS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2035),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: detail.sosHistory.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('Belum ada riwayat SOS', style: TextStyle(color: Colors.white54))),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: detail.sosHistory.length,
                                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                                itemBuilder: (ctx, i) {
                                  final h = detail.sosHistory[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: h.status == 'false_alarm' ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                                      child: Icon(
                                        h.status == 'false_alarm' ? Icons.warning_amber : Icons.emergency,
                                        color: h.status == 'false_alarm' ? Colors.orange : Colors.blue,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(h.incidentType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    subtitle: Text(h.createdAt.toLocal().toString().substring(0, 16), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    trailing: Text(h.status.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Riwayat Laporan Umum', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2035),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: detail.reportHistory.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: Text('Belum ada riwayat laporan', style: TextStyle(color: Colors.white54))),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: detail.reportHistory.length,
                                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                                itemBuilder: (ctx, i) {
                                  final r = detail.reportHistory[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.purple.withOpacity(0.2),
                                      child: const Icon(Icons.report, color: Colors.purple, size: 18),
                                    ),
                                    title: Text(r.incidentType.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    subtitle: Text(r.createdAt.toLocal().toString().substring(0, 16), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    trailing: Text(r.status.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
