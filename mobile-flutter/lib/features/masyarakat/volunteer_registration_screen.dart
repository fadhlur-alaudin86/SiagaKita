import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/localization/app_localization.dart';
import 'dart:async';

class VolunteerRegistrationScreen extends StatefulWidget {
  const VolunteerRegistrationScreen({super.key});

  @override
  State<VolunteerRegistrationScreen> createState() =>
      _VolunteerRegistrationScreenState();
}

class _VolunteerRegistrationScreenState
    extends State<VolunteerRegistrationScreen> {
  final _expCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> _availableSpecs = [
    'Medis & First Aid',
    'Evakuasi & SAR',
    'Logistik & Dapur Umum',
    'Komunikasi & Operator',
  ];

  final Map<String, bool> _selectedSpecs = {};
  final Map<String, bool> _uploadedCerts = {};

  bool _acceptedTerms = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (var spec in _availableSpecs) {
      _selectedSpecs[spec] = false;
      _uploadedCerts[spec] = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrerequisites();
    });
  }

  void _checkPrerequisites() {
    final user = UserModel.currentUser.value;
    List<String> missing = [];

    if (user.nikVerificationStatus != 'approved') {
      missing.add('Verifikasi NIK (KYC)');
    }
    if (user.name.trim().isEmpty) missing.add('Nama Lengkap');
    if (user.birthDate == null || user.birthDate!.isEmpty) {
      missing.add('Tanggal Lahir');
    }
    if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
      missing.add('Nomor Telepon');
    }

    if (missing.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('Persyaratan Belum Lengkap'.tr(context)),
          content: Text(
            'Untuk mendaftar sebagai relawan, lengkapi data profil berikut:\n\n'
                    .tr(context) +
                missing.map((e) => '• $e').join('\n'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Kembali ke profil
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final hasAtLeastOneSpec = _selectedSpecs.values.any((v) => v);
    if (!hasAtLeastOneSpec) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pilih minimal satu spesialisasi'.tr(context))),
      );
      return;
    }

    bool missingCert = false;
    _selectedSpecs.forEach((spec, isSelected) {
      if (isSelected && !_uploadedCerts[spec]!) {
        missingCert = true;
      }
    });

    if (missingCert) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Harap unggah sertifikat untuk setiap spesialisasi yang dipilih'
                .tr(context),
          ),
        ),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Harap centang persetujuan syarat dan ketentuan.'.tr(context),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate API Call to Laravel Backend
    Timer(const Duration(seconds: 2), () {
      final selectedList = _selectedSpecs.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      final user = UserModel.currentUser.value;
      UserModel.currentUser.value = user.copyWith(
        volunteerStatus: 'pending',
        specialization: selectedList.join(', '),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pengajuan Diterima. Status Anda kini Pending Review.'.tr(
                context,
              ),
            ),
          ),
        );
        Navigator.pop(context); // Go back to profile
      }
    });
  }

  Widget _buildMockUploadBox(
    String title,
    bool isUploaded,
    VoidCallback onTap,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final idleBg = isDark
        ? Colors.grey.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.05);
    final idleBorder = isDark
        ? Colors.grey.withValues(alpha: 0.3)
        : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8, bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: isUploaded ? Colors.green.withValues(alpha: 0.1) : idleBg,
          border: Border.all(
            color: isUploaded ? Colors.green : idleBorder,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded
                  ? Colors.green
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUploaded
                        ? 'Sertifikat ${'Tersimpan'.tr(context)}'
                        : '${'Unggah Sertifikat'.tr(context)} $title',
                    style: TextStyle(
                      color: isUploaded
                          ? Colors.green
                          : (isDark ? Colors.white70 : Colors.grey.shade800),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (!isUploaded)
                    Text(
                      '(Tekan untuk simulasi unggah file)'.tr(context),
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0D1B3E);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'PENDAFTARAN RELAWAN'.tr(context),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: const Color(0xFF0D1B3E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Misi Penyelamatan First Responder'.tr(context),
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SiagaKita memanggil Anda yang memiliki kapabilitas medis / evakuasi gawat darurat. Pengajuan akan ditinjau oleh Admin daerah.'
                    .tr(context),
                style: TextStyle(
                  color: isDark
                      ? Colors.white70
                      : colors.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'PILIHAN SPESIALISASI & SERTIFIKAT'.tr(context),
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              
              ..._availableSpecs.map((spec) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text(spec, style: const TextStyle(fontWeight: FontWeight.w600)),
                      value: _selectedSpecs[spec],
                      activeColor: Colors.orange,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setState(() {
                          _selectedSpecs[spec] = val ?? false;
                          if (!val!) _uploadedCerts[spec] = false;
                        });
                      },
                    ),
                    if (_selectedSpecs[spec]!)
                      _buildMockUploadBox(spec, _uploadedCerts[spec]!, () {
                        setState(() => _uploadedCerts[spec] = true);
                      }, context),
                  ],
                );
              }),

              const SizedBox(height: 32),

              Text(
                'PENGALAMAN MEDIS / ORGANISASI'.tr(context),
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _expCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Contoh: Mantan petugas medis PMI, Relawan Damkar...'.tr(
                        context,
                      ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Colors.orange,
                      width: 2,
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Harap uraikan pengalaman Anda'.tr(context)
                    : null,
              ),

              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _acceptedTerms,
                      activeColor: Colors.orange,
                      onChanged: (val) {
                        setState(() => _acceptedTerms = val ?? false);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Saya menyatakan bahwa dokumen yang dilampirkan adalah benar, dan saya bersedia dipanggil dalam situasi darurat di area jangkauan saya sesuai standar operasional yang berlaku.'
                          .tr(context),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : colors.onSurface.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'SUBMIT PENGAJUAN'.tr(context),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
