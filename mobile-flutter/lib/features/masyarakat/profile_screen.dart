import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../../core/localization/app_localization.dart';
import '../../core/models/user_model.dart';
import '../../core/services/session_service.dart';
import '../../core/services/user_service.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'kyc_screen.dart';
import 'volunteer_registration_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String accessToken;
  const ProfileScreen({super.key, required this.accessToken});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Widget _buildVolunteerBadge(UserModel user) {
    if (user.volunteerStatus == 'approved') {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Relawan Terverifikasi'.tr(context),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (user.volunteerStatus == 'pending') {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade600,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Menunggu Verifikasi'.tr(context),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Bukan Relawan'.tr(context),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _editWhatsApp() {
    final phoneCtrl = TextEditingController(text: UserModel.currentUser.value.phoneNumber ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Nomor WhatsApp'.tr(context)),
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Nomor WhatsApp Baru'.tr(context),
            prefixIcon: const Icon(Icons.phone),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal'.tr(context), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final newPhone = phoneCtrl.text.trim();
              if (newPhone.length < 10) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Nomor minimal 10 digit'.tr(context))),
                );
                return;
              }
              Navigator.pop(ctx);
              _requestAndVerifyPhoneOTP(newPhone);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Lanjut'.tr(context), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAndVerifyPhoneOTP(String phoneNumber) async {
    try {
      await UserService.requestPhoneOTP(widget.accessToken, phoneNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim OTP: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (!mounted) return;

    final otpCtrl = TextEditingController();
    bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Verifikasi WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kode OTP telah dikirim ke WhatsApp:\n$phoneNumber\nBerlaku 3 menit.'),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '______',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await UserService.verifyPhoneOTP(
                  widget.accessToken,
                  phoneNumber,
                  otpCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Verifikasi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    otpCtrl.dispose();

    if (verified == true && mounted) {
      try {
        final user = UserModel.currentUser.value;
        final updatedUser = user.copyWith(phoneNumber: phoneNumber);
        await UserService.updateProfile(widget.accessToken, updatedUser);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nomor WhatsApp berhasil diubah dan diverifikasi'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan profil: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic Colors based on theme
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0D1B3E);
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black87;
    final hintColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final cardColor = isDark ? colors.surfaceContainerHighest : Colors.white;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Profil Pengguna'.tr(context),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.orange),
            tooltip: 'Edit Profil'.tr(context),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EditProfileScreen(accessToken: widget.accessToken),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<UserModel>(
        valueListenable: UserModel.currentUser,
        builder: (context, user, _) {
          final medData = user.medicalData ?? {};
          final emContacts = user.emergencyContacts ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (Identitas Utama)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar — gunakan foto profil dari KYC jika tersedia
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              KycScreen(accessToken: widget.accessToken),
                        ),
                      ),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.shade900.withValues(alpha: 0.3)
                              : Colors.blue.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardColor, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: user.profilePhotoUrl != null
                            ? Image.network(
                                'http://139.59.99.230:8080${user.profilePhotoUrl}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.person,
                                  size: 40,
                                  color: primaryTextColor,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 40,
                                color: primaryTextColor,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name +
                                (user.age != null
                                    ? ' (${user.age} ${'Tahun'.tr(context)})'
                                    : ''),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // NIK sebagai identifikasi
                          Row(
                            children: [
                              Icon(Icons.badge, size: 13, color: hintColor),
                              const SizedBox(width: 4),
                              Text(
                                'NIK: ${(user.nik != null && user.nik!.isNotEmpty) ? user.nik : 'Belum diisi'.tr(context)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hintColor,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          _buildVolunteerBadge(user),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. Kategori 1: Informasi Pribadi
                Text(
                  'INFORMASI PRIBADI'.tr(context),
                  style: TextStyle(
                    color: hintColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: cardColor,
                  elevation: isDark ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDark
                        ? BorderSide(color: Colors.grey.withValues(alpha: 0.2))
                        : BorderSide.none,
                  ),
                  child: Column(
                    children: [
                      // NIK (selalu tampil)
                      ListTile(
                        leading: Icon(
                          Icons.badge_outlined,
                          color: primaryTextColor,
                        ),
                        title: Text(
                          'NIK'.tr(context),
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              (user.nik != null && user.nik!.isNotEmpty) ? user.nik! : 'Belum diisi'.tr(context),
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (user.nikVerificationStatus == 'approved')
                              const Icon(Icons.verified, size: 14, color: Colors.green)
                            else if (user.nikVerificationStatus == 'pending')
                              const Icon(Icons.hourglass_top, size: 14, color: Colors.orange)
                            else
                              const Icon(Icons.error_outline, size: 14, color: Colors.red),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KycScreen(accessToken: widget.accessToken),
                            ),
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: Icon(Icons.email, color: primaryTextColor),
                        title: Text(
                          'Email',
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.chat_bubble,
                          color: Color(0xFF25D366),
                        ),
                        title: Text(
                          'Nomor WhatsApp'.tr(context),
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ? user.phoneNumber! : 'Belum diisi'.tr(context),
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (user.isPhoneVerified)
                              const Icon(Icons.verified, size: 14, color: Colors.green)
                            else
                              const Icon(Icons.error_outline, size: 14, color: Colors.red),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: _editWhatsApp,
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: Icon(Icons.cake, color: primaryTextColor),
                        title: Text(
                          'Tanggal Lahir / Umur'.tr(context),
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        subtitle: Text(
                          user.birthDate != null
                              ? '${user.birthDate} (${user.age} ${'Tahun'.tr(context)})'
                              : '-',
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: primaryTextColor,
                        ),
                        title: Text(
                          'Domisili Terkini'.tr(context),
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        subtitle: Text(
                          medData['address'] ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: Icon(Icons.info, color: primaryTextColor),
                        title: Text(
                          'Bio / Deskripsi Profil'.tr(context),
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                        subtitle: Text(
                          (user.bio?.trim().isEmpty ?? true)
                              ? 'Belum ada biodata'.tr(context)
                              : user.bio!,
                          style: TextStyle(
                            fontSize: 14,
                            color: (user.bio?.trim().isEmpty ?? true)
                                ? hintColor
                                : secondaryTextColor,
                            fontStyle: (user.bio?.trim().isEmpty ?? true)
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Kategori 2: Data Medis & Keamanan
                Text(
                  'MEDIS & KEAMANAN'.tr(context),
                  style: TextStyle(
                    color: hintColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: isDark
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.red.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDark
                        ? BorderSide(color: Colors.red.withValues(alpha: 0.2))
                        : BorderSide.none,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.bloodtype, color: Colors.red),
                        title: Text(
                          'Golongan Darah'.tr(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.red.shade300
                                : Colors.redAccent,
                          ),
                        ),
                        subtitle: Text(
                          medData['blood_type'] ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? Colors.red.withValues(alpha: 0.2)
                            : const Color(0xFFFFCDD2),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.monitor_weight_outlined,
                          color: Colors.blue,
                        ),
                        title: Text(
                          'Berat & Tinggi'.tr(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blueAccent,
                          ),
                        ),
                        subtitle: Text(
                          '${medData['weight'] ?? '-'} kg / ${medData['height'] ?? '-'} cm',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? Colors.red.withValues(alpha: 0.2)
                            : const Color(0xFFFFCDD2),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.warning,
                          color: Colors.orange,
                        ),
                        title: Text(
                          'Alergi Utama'.tr(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.red.shade300
                                : Colors.redAccent,
                          ),
                        ),
                        subtitle: Text(
                          medData['allergies'] ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? Colors.red.withValues(alpha: 0.2)
                            : const Color(0xFFFFCDD2),
                      ),
                      ListTile(
                        leading: const Icon(Icons.healing, color: Colors.red),
                        title: Text(
                          'Riwayat Penyakit'.tr(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.red.shade300
                                : Colors.redAccent,
                          ),
                        ),
                        subtitle: Text(
                          medData['medical_history'] ?? '-',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Kategori 3: Kontak Darurat
                Text(
                  'KONTAK DARURAT'.tr(context),
                  style: TextStyle(
                    color: hintColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: cardColor,
                  elevation: isDark ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDark
                        ? BorderSide(color: Colors.grey.withValues(alpha: 0.2))
                        : BorderSide.none,
                  ),
                  child: emContacts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'Tidak ada kontak terdaftar'.tr(context),
                              style: TextStyle(color: hintColor),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: emContacts.length,
                          separatorBuilder: (ctx, idx) => Divider(
                            height: 1,
                            color: isDark
                                ? Colors.grey.withValues(alpha: 0.2)
                                : Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final contact = emContacts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isDark
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : Colors.blue.shade50,
                                child: Icon(
                                  Icons.person,
                                  color: primaryTextColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                contact['name'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                              subtitle: Text(
                                '${contact['relation'] ?? ''} • ${contact['phone'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.call,
                                  color: Colors.green,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${'Memanggil'.tr(context)} ${contact['phone']}...',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 24),

                // 5. Kategori 4: Pengaturan & Bantuan
                Text(
                  'PENGATURAN & BANTUAN'.tr(context),
                  style: TextStyle(
                    color: hintColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: cardColor,
                  elevation: isDark ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDark
                        ? BorderSide(color: Colors.grey.withValues(alpha: 0.2))
                        : BorderSide.none,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.settings, color: primaryTextColor),
                        title: Text(
                          'Pengaturan'.tr(context),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: hintColor),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.info_outline,
                          color: primaryTextColor,
                        ),
                        title: Text(
                          'Tentang Aplikasi'.tr(context),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right, color: hintColor),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 5. Tombol Relawan CTA
                if (user.volunteerStatus != 'approved' &&
                    user.volunteerStatus != 'pending')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.medical_services, size: 20),
                    label: Text(
                      'DAFTAR MENJADI RELAWAN'.tr(context),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VolunteerRegistrationScreen(),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // Logout Button
                OutlinedButton.icon(
                  onPressed: () async {
                    await SessionService.clearSession();
                    // Reset user model
                    UserModel.currentUser.value = const UserModel(
                      id: '',
                      name: '',
                      email: '',
                      role: UserRole.masyarakat,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: Text(
                    'Keluar Aplikasi'.tr(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }
}
