import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import '../../core/localization/app_localization.dart';
import '../../core/services/kyc_service.dart';
import '../../core/widgets/custom_camera_view.dart';

/// KycScreen memungkinkan warga mengajukan verifikasi identitas NIK.
/// Pengguna perlu mengisi NIK 16 digit, nama lengkap, foto KTP, dan foto wajah (selfie).
///
/// Setelah submit berhasil, status menjadi 'pending' dan admin verifikasi
/// dalam 1-3 hari kerja.
class KycScreen extends StatefulWidget {
  final String accessToken;
  const KycScreen({super.key, required this.accessToken});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nikCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  File? _ktpPhoto;
  File? _selfiePhoto;

  bool _isLoading = false;
  bool _submitted = false;

  String _kycStatus = 'none';
  String _kycMessage = '';
  bool _loadingStatus = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _nikCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final data = await KycService.getStatus(accessToken: widget.accessToken);
      if (mounted) {
        setState(() {
          _kycStatus = data['status'] as String? ?? 'none';
          _kycMessage = data['message'] as String? ?? '';
          _loadingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  void _takeSelfie() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomCameraView(
          title: 'Ambil Foto Profil (Selfie)'.tr(context),
          onPictureTaken: (file) {
            if (mounted) {
              setState(() => _selfiePhoto = File(file.path));
            }
          },
        ),
      ),
    );
  }

  void _pickKTP() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomCameraView(
          title: 'Ambil Foto KTP'.tr(context),
          lensDirection: CameraLensDirection.back,
          isOvalOverlay: false,
          onPictureTaken: (file) {
            if (mounted) {
              setState(() => _ktpPhoto = File(file.path));
            }
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ktpPhoto == null) {
      _showSnack('Foto KTP wajib dilampirkan'.tr(context), Colors.orange);
      return;
    }
    if (_selfiePhoto == null) {
      _showSnack(
        'Foto profil (selfie) wajib dilampirkan'.tr(context),
        Colors.orange,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await KycService.submitKYC(
        accessToken: widget.accessToken,
        nik: _nikCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        ktpPhoto: _ktpPhoto!,
        selfiePhoto: _selfiePhoto!,
      );
      if (mounted) {
        setState(() {
          _submitted = true;
          _kycStatus = 'pending';
          _kycMessage =
              'Pengajuan sedang diproses oleh admin (1-3 hari kerja).';
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''), Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = isDark ? const Color(0xFF162A5A) : Colors.white;
    final bgColor = isDark ? const Color(0xFF0D1B3E) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Verifikasi Identitas (KYC)'.tr(context),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 16,
          ),
        ),
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  _buildStatusBanner(isDark),
                  const SizedBox(height: 20),

                  // Hanya tampilkan form jika status none atau rejected
                  if (_kycStatus == 'none' || _kycStatus == 'rejected') ...[
                    _buildInfoCard(cardColor, textColor, primary),
                    const SizedBox(height: 20),
                    _buildForm(cardColor, textColor, primary, isDark),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBanner(bool isDark) {
    final config = switch (_kycStatus) {
      'approved' => (
        color: Colors.green,
        icon: Icons.verified_user,
        label: 'Terverifikasi',
      ),
      'pending' => (
        color: Colors.orange,
        icon: Icons.hourglass_top,
        label: 'Menunggu Verifikasi',
      ),
      'rejected' => (
        color: Colors.red,
        icon: Icons.cancel_outlined,
        label: 'Ditolak',
      ),
      _ => (
        color: Colors.grey,
        icon: Icons.person_outlined,
        label: 'Belum Diverifikasi',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, color: config.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${config.label}'.tr(context),
                  style: TextStyle(
                    color: config.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (_kycMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _kycMessage,
                    style: TextStyle(
                      color: config.color.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Color cardColor, Color textColor, Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Mengapa perlu verifikasi?'.tr(context),
                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Verifikasi NIK dan wajah meningkatkan kepercayaan responden terhadap laporan darurat Anda '
            'dan akan digunakan sebagai foto profil resmi Anda di aplikasi.',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Data diproses dalam 1-3 hari kerja\n'
            '• Wajah harus terlihat jelas tanpa aksesoris penutup\n'
            '• NIK terenkripsi dan aman',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    Color cardColor,
    Color textColor,
    Color primary,
    bool isDark,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NIK Field
          Text(
            'NIK (16 digit)'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nikCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            style: TextStyle(color: textColor),
            decoration: _inputDecoration('Masukkan 16 digit NIK KTP', isDark),
            validator: (v) {
              if (v == null || v.isEmpty) return 'NIK wajib diisi';
              if (v.length != 16) return 'NIK harus tepat 16 digit';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Nama Lengkap Field
          Text(
            'Nama Lengkap (sesuai KTP)'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: textColor),
            decoration: _inputDecoration('Masukkan nama sesuai KTP', isDark),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
              if (v.trim().length < 3) return 'Nama terlalu pendek';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Foto KTP
          Text(
            'Foto KTP'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildPhotoSelector(
            label: _ktpPhoto == null
                ? 'Ambil / Pilih Foto KTP'.tr(context)
                : 'KTP terpilih ✓'.tr(context),
            photo: _ktpPhoto,
            color: _ktpPhoto != null ? Colors.green : primary,
            icon: Icons.badge_outlined,
            onCamera: _pickKTP,
            onGallery: null,
            cardColor: cardColor,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Selfie (wajib dan ganti foto profil)
          Text(
            'Foto Profil (Selfie)'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildPhotoSelector(
            label: _selfiePhoto == null
                ? 'Ambil Selfie Wajah'.tr(context)
                : 'Selfie terpilih ✓'.tr(context),
            photo: _selfiePhoto,
            color: _selfiePhoto != null ? Colors.green : Colors.blueGrey,
            icon: Icons.camera_front,
            onCamera: _takeSelfie,
            onGallery: null,
            cardColor: cardColor,
            isDark: isDark,
          ),
          const SizedBox(height: 32),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading || _submitted ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: primary.withValues(alpha: 0.4),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _isLoading
                    ? 'Mengirim...'.tr(context)
                    : 'Ajukan Verifikasi NIK'.tr(context),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPhotoSelector({
    required String label,
    required File? photo,
    required Color color,
    required IconData icon,
    required VoidCallback onCamera,
    VoidCallback? onGallery,
    required Color cardColor,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: photo != null
              ? Colors.green.withValues(alpha: 0.4)
              : (isDark ? Colors.white24 : Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          if (photo != null) ...[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: Image.file(
                photo,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                ),

                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(
                    photo == null ? 'Kamera' : 'Ulang',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontSize: 13,
      ),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
