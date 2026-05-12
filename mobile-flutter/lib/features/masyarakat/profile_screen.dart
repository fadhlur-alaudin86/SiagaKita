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
import 'report_history_screen.dart';

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

  // ─── Card Reputasi Relawan ────────────────────────────────────────────────
  Widget _buildVolunteerReputationCard(
    UserModel user,
    bool isDark,
    Color hintColor,
  ) {
    final xp = user.volunteerPoints;
    final level = user.volunteerLevel;
    final nextThreshold = xp < 100
        ? 100
        : xp < 500
        ? 500
        : xp < 1500
        ? 1500
        : 9999;
    final prevThreshold = xp < 100
        ? 0
        : xp < 500
        ? 100
        : xp < 1500
        ? 500
        : 1500;
    final progress = nextThreshold == 9999
        ? 1.0
        : (xp - prevThreshold) / (nextThreshold - prevThreshold);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2F1A), const Color(0xFF142B22)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.military_tech,
                color: Color(0xFFFBBF24),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'REPUTASI RELAWAN',
                style: TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _reputationStat(
                  'XP',
                  '$xp',
                  Icons.star_outline,
                  const Color(0xFFFBBF24),
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _reputationStat(
                  'Level',
                  level,
                  Icons.shield_outlined,
                  const Color(0xFF22C55E),
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                nextThreshold == 9999
                    ? 'Level Maksimal'
                    : 'Menuju $nextThreshold XP',
                style: TextStyle(fontSize: 11, color: hintColor),
              ),
              const Spacer(),
              Text(
                nextThreshold == 9999 ? '100%' : '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.green.shade100,
              color: const Color(0xFF22C55E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reputationStat(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Konfirmasi sebelum edit NIK ─────────────────────────────────────────
  void _confirmAndEditNIK() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Perhatian'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Perubahan NIK membutuhkan verifikasi ulang oleh admin (1-3 hari kerja). '
          'Status verifikasi saat ini akan direset ke "pending".\n\nApakah Anda ingin melanjutkan?',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal'.tr(context),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(
              'Lanjut'.tr(context),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KycScreen(accessToken: widget.accessToken),
          ),
        );
      }
    });
  }

  // ─── Konfirmasi sebelum edit WhatsApp ─────────────────────────────────────
  void _confirmAndEditWhatsApp() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Perhatian'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Pengubahan nomor WhatsApp memerlukan verifikasi ulang melalui OTP. '
          'Nomor baru tidak dapat digunakan sebelum terverifikasi.\n\nApakah Anda ingin melanjutkan?',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal'.tr(context),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(
              'Lanjut'.tr(context),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        _editWhatsApp();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Refresh data terbaru dari server saat membuka profil
    UserService.refreshCurrentUser(widget.accessToken);
  }

  void _editWhatsApp() {
    final phoneCtrl = TextEditingController(
      text: UserModel.currentUser.value.phoneNumber ?? '',
    );
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
            child: Text(
              'Batal'.tr(context),
              style: const TextStyle(color: Colors.grey),
            ),
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
            child: Text(
              'Lanjut'.tr(context),
              style: const TextStyle(color: Colors.white),
            ),
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
          SnackBar(
            content: Text('Gagal mengirim OTP: $e'),
            backgroundColor: Colors.red,
          ),
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
            Text(
              'Kode OTP telah dikirim ke WhatsApp:\n$phoneNumber\nBerlaku 3 menit.',
            ),
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
            child: const Text(
              'Verifikasi',
              style: TextStyle(color: Colors.white),
            ),
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
        
        // Refresh global state untuk mendapatkan status isPhoneVerified terbaru
        await UserService.refreshCurrentUser(widget.accessToken);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nomor WhatsApp berhasil diubah dan diverifikasi'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan profil: $e'),
            backgroundColor: Colors.red,
          ),
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
                    // Avatar - gunakan foto profil dari KYC jika tersedia
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
                            (user.name.isNotEmpty ? user.name : 'Pengguna'.tr(context)) +
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

                // Bio Singkat
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  Text(
                    user.bio!,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Text(
                    'Belum ada bio.'.tr(context),
                    style: TextStyle(
                      fontSize: 13,
                      color: hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                              (user.nik != null && user.nik!.isNotEmpty)
                                  ? user.nik!
                                  : 'Belum diisi'.tr(context),
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (user.nikVerificationStatus == 'approved')
                              const Icon(
                                Icons.verified,
                                size: 14,
                                color: Colors.green,
                              )
                            else if (user.nikVerificationStatus == 'pending')
                              const Icon(
                                Icons.hourglass_top,
                                size: 14,
                                color: Colors.orange,
                              )
                            else
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Colors.red,
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: _confirmAndEditNIK,
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
                        color: isDark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.shade200,
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
                              (user.phoneNumber != null &&
                                      user.phoneNumber!.isNotEmpty)
                                  ? user.phoneNumber!
                                  : 'Belum diisi'.tr(context),
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (user.isPhoneVerified)
                              const Icon(
                                Icons.verified,
                                size: 14,
                                color: Colors.green,
                              )
                            else
                              const Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Colors.red,
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: _confirmAndEditWhatsApp,
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

                // 4. Kategori 4: Riwayat
                Text(
                  'RIWAYAT'.tr(context),
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
                  child: ListTile(
                    leading: Icon(
                      Icons.history_outlined,
                      color: primaryTextColor,
                    ),
                    title: Text(
                      'Riwayat Laporan'.tr(context),
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
                          builder: (_) => ReportHistoryScreen(
                            accessToken: widget.accessToken,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // 5. Kategori 5: Pengaturan & Bantuan
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

                // 5b. Reputasi Relawan (hanya tampil jika sudah approved)
                if (user.volunteerStatus == 'approved') ...[
                  const SizedBox(height: 8),
                  _buildVolunteerReputationCard(user, isDark, hintColor),
                ],

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
