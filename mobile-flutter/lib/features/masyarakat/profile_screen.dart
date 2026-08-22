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
import 'wa_verification_screen.dart';

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

    // 5-tier thresholds
    final nextThreshold = xp < 100
        ? 100
        : xp < 500
        ? 500
        : xp < 2000
        ? 2000
        : xp < 5000
        ? 5000
        : 99999;
    final prevThreshold = xp < 100
        ? 0
        : xp < 500
        ? 100
        : xp < 2000
        ? 500
        : xp < 5000
        ? 2000
        : 5000;
    final progress = nextThreshold == 99999
        ? 1.0
        : (xp - prevThreshold) / (nextThreshold - prevThreshold);

    // Warna berdasarkan rank tier
    final Color rankColor;
    final List<Color> gradientDark;
    final List<Color> gradientLight;
    if (xp >= 5000) {
      // Ahli: merah premium
      rankColor = const Color(0xFFDC2626);
      gradientDark = [const Color(0xFF2F1A1A), const Color(0xFF2B1414)];
      gradientLight = [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)];
    } else if (xp >= 2000) {
      // Veteran: emas
      rankColor = const Color(0xFFF59E0B);
      gradientDark = [const Color(0xFF2F2A1A), const Color(0xFF2B2214)];
      gradientLight = [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)];
    } else if (xp >= 500) {
      // Profesional: ungu
      rankColor = const Color(0xFF8B5CF6);
      gradientDark = [const Color(0xFF1F1A2F), const Color(0xFF1A142B)];
      gradientLight = [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)];
    } else if (xp >= 100) {
      // Menengah: biru
      rankColor = const Color(0xFF3B82F6);
      gradientDark = [const Color(0xFF1A1F2F), const Color(0xFF14192B)];
      gradientLight = [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)];
    } else {
      // Pemula: hijau (default)
      rankColor = const Color(0xFF22C55E);
      gradientDark = [const Color(0xFF1A2F1A), const Color(0xFF142B22)];
      gradientLight = [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? gradientDark : gradientLight,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rankColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech, color: rankColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'REPUTASI RELAWAN'.tr(context),
                style: TextStyle(
                  color: rankColor,
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
                  'XP'.tr(context),
                  '$xp',
                  Icons.star_outline,
                  rankColor,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _reputationStat(
                  'Level'.tr(context),
                  level,
                  Icons.shield_outlined,
                  rankColor,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                nextThreshold == 99999
                    ? 'Level Maksimal'.tr(context)
                    : '${'Menuju '.tr(context)}$nextThreshold XP',
                style: TextStyle(fontSize: 11, color: hintColor),
              ),
              const Spacer(),
              Text(
                nextThreshold == 99999
                    ? '100%'
                    : '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: rankColor,
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
              backgroundColor: isDark
                  ? Colors.white12
                  : rankColor.withValues(alpha: 0.15),
              color: rankColor,
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
          'Perubahan NIK membutuhkan verifikasi ulang oleh admin (1-3 hari kerja). Status verifikasi saat ini akan direset ke "Menunggu Verifikasi".\n\nApakah Anda ingin melanjutkan?'
              .tr(context),
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
          'Pengubahan nomor WhatsApp memerlukan verifikasi ulang melalui OTP. Tingkat kepercayaan laporan Anda akan berkurang jika nomor belum diverifikasi.\n\nApakah Anda ingin melanjutkan?'
              .tr(context),
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
            builder: (_) => WaVerificationScreen(
              accessToken: widget.accessToken,
              initialPhoneNumber: UserModel.currentUser.value.phoneNumber,
            ),
          ),
        );
      }
    });
  }

  // ─── Dialog Pembatasan Relawan ──────────────────────────────────────────
  void _showRestrictedVolunteerDialog(UserModel user) {
    final List<Map<String, dynamic>> requirements = [
      {
        'title': 'Verifikasi NIK (KYC)'.tr(context),
        'isVerified': user.nikVerificationStatus == 'approved',
      },
      {
        'title': 'Verifikasi Nomor WhatsApp'.tr(context),
        'isVerified': user.isPhoneVerified,
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Persyaratan Belum Lengkap'.tr(context),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Untuk mendaftar sebagai relawan, Anda wajib melengkapi verifikasi berikut:'
                  .tr(context),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            ...requirements.map(
              (req) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      req['isVerified'] ? Icons.check_circle : Icons.cancel,
                      size: 20,
                      color: req['isVerified'] ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        req['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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

  @override
  void initState() {
    super.initState();
    // Refresh data terbaru dari server saat membuka profil
    UserService.refreshCurrentUser(widget.accessToken);
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
          'PROFIL PENGGUNA'.tr(context),
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 20,
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

          return RefreshIndicator(
            onRefresh: () async {
              await UserService.refreshCurrentUser(widget.accessToken);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                              user.name.isNotEmpty
                                  ? user.name
                                  : 'Pengguna'.tr(context),
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
                          ? BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2),
                            )
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
                          trailing: user.nikVerificationStatus == 'pending'
                              ? null
                              : (user.nik != null &&
                                    user.nikVerificationStatus == 'none')
                              ? TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => KycScreen(
                                        accessToken: widget.accessToken,
                                      ),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(60, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Verifikasi'.tr(context),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : IconButton(
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
                          trailing:
                              (user.phoneNumber != null &&
                                  user.phoneNumber!.isNotEmpty &&
                                  !user.isPhoneVerified)
                              ? TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => WaVerificationScreen(
                                          accessToken: widget.accessToken,
                                          initialPhoneNumber: user.phoneNumber,
                                        ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(60, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Verifikasi'.tr(context),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : IconButton(
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
                            'Tempat, Tanggal Lahir (Umur)'.tr(context),
                            style: TextStyle(fontSize: 12, color: hintColor),
                          ),
                          subtitle: Text(
                            (user.placeOfBirth != null &&
                                    user.birthDate != null)
                                ? '${user.placeOfBirth}, ${user.birthDate} (${user.age} ${'Tahun'.tr(context)})'
                                : (user.birthDate != null)
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
                          leading: const Icon(
                            Icons.bloodtype,
                            color: Colors.red,
                          ),
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
                          ? BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2),
                            )
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
                          ? BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2),
                            )
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
                          ? BorderSide(
                              color: Colors.grey.withValues(alpha: 0.2),
                            )
                          : BorderSide.none,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.settings,
                            color: primaryTextColor,
                          ),
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
                      user.volunteerStatus != 'pending') ...[
                    Builder(
                      builder: (context) {
                        final bool isVerified =
                            user.isPhoneVerified &&
                            user.nikVerificationStatus == 'approved';

                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isVerified
                                ? Colors.orange
                                : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            elevation: isVerified ? 4 : 0,
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
                            if (isVerified) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const VolunteerRegistrationScreen(),
                                ),
                              );
                            } else {
                              _showRestrictedVolunteerDialog(user);
                            }
                          },
                        );
                      },
                    ),
                  ],

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
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: Text(
                      'Keluar'.tr(context),
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
            ),
          );
        },
      ),
    );
  }
}
