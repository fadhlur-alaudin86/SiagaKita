import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import '../../core/localization/app_localization.dart';
import '../../core/services/kyc_service.dart';
import '../../core/services/user_service.dart';
import '../../core/models/user_model.dart';
import '../../core/widgets/custom_camera_view.dart';
import '../../core/utils/responsive.dart';

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
  final _placeOfBirthCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

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
    _placeOfBirthCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final user = UserModel.currentUser.value;
    if (user.nik != null) _nikCtrl.text = user.nik!;
    if (user.name.isNotEmpty) _nameCtrl.text = user.name;
    if (user.placeOfBirth != null) _placeOfBirthCtrl.text = user.placeOfBirth!;
    if (user.birthDate != null) _birthDateCtrl.text = user.birthDate!;

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
        placeOfBirth: _placeOfBirthCtrl.text.trim(),
        dateOfBirth: _birthDateCtrl.text.trim(),
        ktpPhoto: _ktpPhoto!,
        selfiePhoto: _selfiePhoto!,
      );

      // Refresh global state agar status NIK berubah jadi 'pending'
      await UserService.refreshCurrentUser(widget.accessToken);

      if (mounted) {
        setState(() {
          _submitted = true;
          _kycStatus = 'pending';
          _kycMessage = 'Pengajuan sedang diproses oleh admin (1-3 hari kerja).'
              .tr(context);
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        final isNikDuplicate = msg.contains('sudah terdaftar');
        _showSnack(
          isNikDuplicate ? msg : msg,
          isNikDuplicate ? Colors.red.shade700 : Colors.red,
        );
        // Jika NIK sudah digunakan, fokuskan kembali ke field NIK
        if (isNikDuplicate) {
          _nikCtrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _nikCtrl.text.length,
          );
        }
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
          'Verifikasi Identitas'.tr(context),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 16.sp(context),
          ),
        ),
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20.w(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  _buildStatusBanner(isDark),
                  SizedBox(height: 20.h(context)),

                  _buildInfoCard(cardColor, textColor, primary),
                  SizedBox(height: 20.h(context)),
                  _buildForm(cardColor, textColor, primary, isDark),
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
      padding: EdgeInsets.all(16.w(context)),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16.w(context)),
        border: Border.all(color: config.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w(context)),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, color: config.color, size: 28.w(context)),
          ),
          SizedBox(width: 16.w(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: '.tr(context) + config.label.tr(context),
                  style: TextStyle(
                    color: config.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp(context),
                  ),
                ),
                if (_kycMessage.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _kycMessage,
                    style: TextStyle(
                      color: config.color.withValues(alpha: 0.8),
                      fontSize: 13.sp(context),
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
      padding: EdgeInsets.all(16.w(context)),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.w(context)),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: primary, size: 18.w(context)),
              SizedBox(width: 8.w(context)),
              Text(
                'Mengapa perlu verifikasi?'.tr(context),
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h(context)),
          Text(
            'Verifikasi NIK dan wajah meningkatkan kepercayaan responden terhadap laporan darurat Anda dan akan digunakan sebagai foto profil resmi Anda di aplikasi.'
                .tr(context),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 13.sp(context),
            ),
          ),
          SizedBox(height: 8.h(context)),
          Text(
            '• Data diproses dalam 1-3 hari kerja\n'
                    '• Wajah harus terlihat jelas tanpa aksesoris penutup\n'
                    '• NIK terenkripsi dan aman'
                .tr(context),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 12.sp(context),
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
              fontSize: 14.sp(context),
            ),
          ),
          SizedBox(height: 8.h(context)),
          TextFormField(
            controller: _nikCtrl,
            maxLength: 16,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
            ],
            style: TextStyle(color: textColor),
            decoration: _inputDecoration(
              'Masukkan 16 digit NIK KTP'.tr(context),
              isDark,
              context,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'NIK wajib diisi'.tr(context);
              if (v.length != 16) return 'NIK harus tepat 16 digit'.tr(context);
              return null;
            },
          ),
          SizedBox(height: 16.h(context)),

          // Nama Lengkap Field
          Text(
            'Nama Lengkap (sesuai KTP)'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp(context),
            ),
          ),
          SizedBox(height: 8.h(context)),
          TextFormField(
            controller: _nameCtrl,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: textColor, fontSize: 14.sp(context)),
            decoration: _inputDecoration(
              'Masukkan nama sesuai KTP'.tr(context),
              isDark,
              context,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Nama wajib diisi'.tr(context);
              }
              if (v.trim().length < 3) return 'Nama terlalu pendek'.tr(context);
              return null;
            },
          ),
          SizedBox(height: 16.h(context)),

          // Tempat Lahir
          Text(
            'Tempat Lahir'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp(context),
            ),
          ),
          SizedBox(height: 8.h(context)),
          TextFormField(
            controller: _placeOfBirthCtrl,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: textColor, fontSize: 14.sp(context)),
            decoration: _inputDecoration(
              'Sesuai KTP'.tr(context),
              isDark,
              context,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Tempat lahir wajib diisi'.tr(context);
              }
              return null;
            },
          ),
          SizedBox(height: 16.h(context)),

          // Tanggal Lahir
          Text(
            'Tanggal Lahir (DD-MM-YYYY)'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp(context),
            ),
          ),
          SizedBox(height: 8.h(context)),
          TextFormField(
            controller: _birthDateCtrl,
            readOnly: true,
            onTap: () async {
              DateTime initialDate = DateTime(2000, 1, 1);
              if (_birthDateCtrl.text.isNotEmpty) {
                try {
                  final parts = _birthDateCtrl.text.split('-');
                  if (parts.length == 3) {
                    if (parts[0].length == 4) {
                      initialDate = DateTime.parse(_birthDateCtrl.text);
                    } else {
                      initialDate = DateTime(
                        int.parse(parts[2]),
                        int.parse(parts[1]),
                        int.parse(parts[0]),
                      );
                    }
                  }
                } catch (_) {}
              }
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _birthDateCtrl.text =
                      "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                });
              }
            },
            style: TextStyle(color: textColor, fontSize: 14.sp(context)),
            decoration: _inputDecoration(
              'Sesuai KTP'.tr(context),
              isDark,
              context,
            ).copyWith(suffixIcon: Icon(Icons.calendar_today, color: primary)),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Tanggal lahir wajib diisi'.tr(context);
              }
              return null;
            },
          ),
          SizedBox(height: 24.h(context)),

          // Foto KTP
          Text(
            'Foto KTP'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp(context),
            ),
          ),
          SizedBox(height: 8.h(context)),
          _buildPhotoSelector(
            label: _ktpPhoto == null
                ? 'Ambil / Pilih Foto KTP'.tr(context)
                : 'KTP terpilih'.tr(context),
            photo: _ktpPhoto,
            color: _ktpPhoto != null ? Colors.green : primary,
            icon: Icons.badge_outlined,
            onCamera: _pickKTP,
            onGallery: null,
            cardColor: cardColor,
            isDark: isDark,
          ),
          SizedBox(height: 16.h(context)),

          // Selfie (wajib dan ganti foto profil)
          Text(
            'Foto Profil (Selfie)'.tr(context),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14.sp(context),
            ),
          ),
          SizedBox(height: 8.h(context)),
          _buildPhotoSelector(
            label: _selfiePhoto == null
                ? 'Ambil Selfie Wajah'.tr(context)
                : 'Selfie terpilih'.tr(context),
            photo: _selfiePhoto,
            color: _selfiePhoto != null ? Colors.green : Colors.blueGrey,
            icon: Icons.camera_front,
            onCamera: _takeSelfie,
            onGallery: null,
            cardColor: cardColor,
            isDark: isDark,
          ),
          SizedBox(height: 32.h(context)),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading || _submitted ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.w(context)),
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
                  : Icon(Icons.send_outlined, size: 20.w(context)),
              label: Text(
                _isLoading
                    ? 'Mengirim...'.tr(context)
                    : 'Ajukan Verifikasi NIK'.tr(context),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.sp(context),
                ),
              ),
            ),
          ),
          SizedBox(height: 40.h(context)),
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
        borderRadius: BorderRadius.circular(12.w(context)),
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
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(11.w(context)),
              ),
              child: Image.file(
                photo,
                height: 160.h(context),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.w(context),
              vertical: 12.h(context),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20.w(context)),
                SizedBox(width: 10.w(context)),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                      fontSize: 13.sp(context),
                    ),
                  ),
                ),

                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: onCamera,
                  icon: Icon(Icons.camera_alt_outlined, size: 16.w(context)),
                  label: Text(
                    photo == null ? 'Kamera'.tr(context) : 'Ulang'.tr(context),
                    style: TextStyle(fontSize: 12.sp(context)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w(context),
                      vertical: 6.h(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.w(context)),
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

  InputDecoration _inputDecoration(
    String hint,
    bool isDark,
    BuildContext context,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontSize: 13.sp(context),
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
        borderRadius: BorderRadius.circular(12.w(context)),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.w(context)),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2.w(context),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.w(context)),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16.w(context),
        vertical: 14.h(context),
      ),
    );
  }
}
