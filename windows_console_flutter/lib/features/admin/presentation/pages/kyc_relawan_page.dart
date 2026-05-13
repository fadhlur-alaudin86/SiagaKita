import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/models/models.dart';
import '../../../../core/services/api_services.dart';

class KycRelawanPage extends StatefulWidget {
  final String token;
  const KycRelawanPage({super.key, required this.token});

  @override
  State<KycRelawanPage> createState() => _KycRelawanPageState();
}

class _KycRelawanPageState extends State<KycRelawanPage> {
  List<VolunteerModel> _volunteers = [];
  VolunteerModel? _selected;
  bool _loading = true;
  String? _error;
  Timer? _timer;
  final _rejectCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rejectCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await AdminApiService.getPendingVolunteers(widget.token);
      if (mounted) {
        setState(() {
          _volunteers = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Gagal memuat data: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _approve() async {
    if (_selected == null) return;
    final ok = await AdminApiService.approveVolunteer(
      widget.token,
      _selected!.id,
    );
    if (!mounted) return;
    if (ok) {
      _showSnack(
        '✅ ${_selected!.fullName} disetujui sebagai relawan.',
        Colors.green,
      );
      setState(() => _selected = null);
      _load();
    } else {
      _showSnack('Gagal menyetujui. Coba lagi.', Colors.red);
    }
  }

  Future<void> _reject() async {
    if (_selected == null) return;
    _rejectCtrl.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2537),
        title: const Text(
          'Tolak Pendaftaran',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alasan penolakan untuk ${_selected!.fullName}:',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Contoh: Foto KTP tidak jelas',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (confirmed != true || _rejectCtrl.text.isEmpty) return;
    final ok = await AdminApiService.rejectVolunteer(
      widget.token,
      _selected!.id,
      _rejectCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      _showSnack(
        '❌ Pendaftaran ${_selected!.fullName} ditolak.',
        Colors.orange,
      );
      setState(() => _selected = null);
      _load();
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Kiri: Antrian KYC ──────────────────────────────────────────────
        SizedBox(
          width: 300,
          child: Card(
            color: const Color(0xFF1A2035),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Antrian KYC',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (!_loading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${_volunteers.length}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off,
                                  color: Colors.red,
                                  size: 36,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text(
                                    'Coba Lagi',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _volunteers.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada antrian',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _volunteers.length,
                          itemBuilder: (_, i) {
                            final v = _volunteers[i];
                            final isSelected = _selected?.id == v.id;
                            return Material(
                              color: isSelected
                                  ? const Color(
                                      0xFFFF7418,
                                    ).withValues(alpha: 0.15)
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() => _selected = v),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: Colors.orange
                                            .withValues(alpha: 0.2),
                                        child: Text(
                                          v.fullName.isNotEmpty
                                              ? v.fullName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              v.fullName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              v.email,
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFFFF7418),
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 16),

        // ── Kanan: Detail & Aksi ───────────────────────────────────────────
        Expanded(
          child: _selected == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        color: Colors.white24,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Pilih relawan dari daftar untuk verifikasi',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ],
                  ),
                )
              : _buildDetailPanel(_selected!),
        ),
      ],
    );
  }

  Widget _buildDetailPanel(VolunteerModel v) {
    return Card(
      color: const Color(0xFF1A2035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.orange.withValues(alpha: 0.2),
                  child: Text(
                    v.fullName.isNotEmpty ? v.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.orange, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      v.email,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    if (v.phoneNumber != null)
                      Text(
                        v.phoneNumber!,
                        style: const TextStyle(color: Colors.white54),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),

            // NIK
            _DetailRow(label: 'NIK', value: v.nik ?? '-'),
            const SizedBox(height: 16),

            // Foto KTP
            const Text(
              'Foto KTP:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (v.nikPhotoUrl != null && v.nikPhotoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  v.nikPhotoUrl!,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 100,
                    color: Colors.white10,
                    child: const Center(
                      child: Text(
                        'Gagal memuat foto',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Text(
                'Tidak ada foto KTP',
                style: TextStyle(color: Colors.white38),
              ),

            const SizedBox(height: 20),

            // Sertifikat
            const Text(
              'Sertifikat:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (v.certs.isEmpty)
              const Text(
                'Tidak ada sertifikat',
                style: TextStyle(color: Colors.white38),
              )
            else
              ...v.certs.asMap().entries.map(
                (e) => _buildCertViewer(e.key + 1, e.value),
              ),

            const SizedBox(height: 20),

            // Pengalaman & Spesialisasi
            const Text(
              'Pengalaman & Spesialisasi:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                v.experience ?? 'Tidak ada pengalaman yang ditulis',
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      'TOLAK',
                      style: TextStyle(letterSpacing: 1),
                    ),
                    onPressed: _reject,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2EAF60),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'APPROVE RELAWAN',
                      style: TextStyle(
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _approve,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Menampilkan preview sertifikat: PDF inline (pdfrx) atau gambar (Image.network).
  Widget _buildCertViewer(int index, VolunteerCert cert) {
    final ext = cert.url.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label tipe
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Colors.orange,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$index. ${cert.type}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Area preview kecil (Thumbnail)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showFullScreenCert(cert),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 120,
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: isPdf
                          ? IgnorePointer(
                              child: PdfViewer.uri(
                                Uri.parse(cert.url),
                                params: const PdfViewerParams(
                                  backgroundColor: Color(0xFF1A2035),
                                ),
                              ),
                            )
                          : isImage
                          ? Image.network(
                              cert.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_not_supported,
                                color: Colors.white24,
                              ),
                            )
                          : const Icon(
                              Icons.insert_drive_file,
                              color: Colors.white24,
                              size: 40,
                            ),
                    ),
                    // Overlay klik
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.fullscreen,
                            color: Colors.white70,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenCert(VolunteerCert cert) {
    final ext = cert.url.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        child: Stack(
          children: [
            // Konten utama
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
                child: Center(
                  child: isPdf
                      ? PdfViewer.uri(
                          Uri.parse(cert.url),
                          params: const PdfViewerParams(
                            backgroundColor: Colors.transparent,
                          ),
                        )
                      : InteractiveViewer(
                          maxScale: 5.0,
                          minScale: 0.5,
                          child: Image.network(
                            cert.url,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                ? child
                                : const CircularProgressIndicator(
                                    color: Colors.orange,
                                  ),
                          ),
                        ),
                ),
              ),
            ),
            // Header Dialog
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                color: Colors.black45,
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cert.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
