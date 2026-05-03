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
  String? _selectedSpecialization;

  bool _hasMockKtp = false;
  bool _hasMockSertifikat = false;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasMockKtp || !_hasMockSertifikat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Anda wajib mengunggah KTP dan Sertifikat Keahlian (atau simulasikan dengan menekan kotak upload)'
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
      final user = UserModel.currentUser.value;
      UserModel.currentUser.value = user.copyWith(
        volunteerStatus: 'pending',
        specialization: _selectedSpecialization,
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
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isUploaded ? Colors.green.withValues(alpha: 0.1) : idleBg,
          border: Border.all(
            color: isUploaded ? Colors.green : idleBorder,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded
                  ? Colors.green
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              isUploaded
                  ? '$title ${'Tersimpan'.tr(context)}'
                  : '${'Unggah'.tr(context)} $title',
              style: TextStyle(
                color: isUploaded
                    ? Colors.green
                    : (isDark ? Colors.white70 : Colors.grey.shade800),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isUploaded)
              Text(
                '(Tekan untuk simulasi unggah file)'.tr(context),
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  fontSize: 10,
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
                'PILIHAN SPESIALISASI'.tr(context),
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedSpecialization,
                decoration: InputDecoration(
                  labelText: 'Keahlian Relawan'.tr(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items:
                    [
                          'Medis & First Aid',
                          'Evakuasi & SAR',
                          'Logistik & Dapur Umum',
                          'Komunikasi & Operator',
                        ]
                        .map(
                          (val) =>
                              DropdownMenuItem(value: val, child: Text(val)),
                        )
                        .toList(),
                onChanged: (val) {
                  setState(() => _selectedSpecialization = val);
                },
                validator: (v) =>
                    v == null ? 'Wajib memilih spesialisasi'.tr(context) : null,
              ),

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
              Text(
                'VERIFIKASI DOKUMEN'.tr(context),
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              _buildMockUploadBox('Foto KTP'.tr(context), _hasMockKtp, () {
                setState(() => _hasMockKtp = true);
              }, context),
              const SizedBox(height: 16),
              _buildMockUploadBox(
                'Sertifikat Keahlian'.tr(context),
                _hasMockSertifikat,
                () {
                  setState(() => _hasMockSertifikat = true);
                },
                context,
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
