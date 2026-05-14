import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/localization/app_localization.dart';
import '../../core/services/location_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_model.dart';
import '../auth/reset_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  // Mock states for settings toggles
  bool _pushNotifications = true;
  bool _smsAlerts = false;
  bool _locationTracking = false;
  late String _language;
  static const List<String> _availableLanguages = <String>[
    'Bahasa Indonesia',
    'English',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _language =
        SiagaKitaApp.localeNotifier.value.languageCode ==
            AppLocalization.localeEn.languageCode
        ? 'English'
        : 'Bahasa Indonesia';
    _checkLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermission();
    }
  }

  Future<void> _checkLocationPermission() async {
    final hasPerm = await LocationService.hasPermission();
    if (mounted && _locationTracking != hasPerm) {
      setState(() => _locationTracking = hasPerm);
    }
  }

  Future<void> _onCameraGalleryTap() async {
    final cameraStatus = await Permission.camera.status;
    final storageStatus = await Permission.photos.status;
    final cameraGranted = cameraStatus.isGranted;
    final storageGranted = storageStatus.isGranted;

    if (cameraGranted && storageGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Izin kamera & galeri sudah diberikan.'.tr(context)),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    // Minta izin yang belum diberikan
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.photos,
    ].request();

    if (!mounted) return;
    final allGranted = statuses.values.every((s) => s.isGranted);
    if (!allGranted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Izin Diperlukan'.tr(context),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Izin kamera atau galeri ditolak. Buka pengaturan perangkat untuk mengaktifkannya secara manual.'
                .tr(context),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: Text('Buka Pengaturan'.tr(context)),
            ),
          ],
        ),
      );
    }
  }

  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.construction_outlined, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Segera Hadir'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '$featureName ${'sedang dalam tahap pengembangan dan akan segera tersedia.'.tr(context)}',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Mengerti'.tr(context)),
          ),
        ],
      ),
    );
  }

  void _onLocationToggle(bool val) async {
    if (val) {
      final granted = await LocationService.requestPermission(context);
      if (mounted) setState(() => _locationTracking = granted);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Cabut Izin Lokasi'.tr(context),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Untuk mencabut izin lokasi, Anda perlu melakukannya secara manual melalui pengaturan OS perangkat Anda.'
                .tr(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: Text('Buka Pengaturan'.tr(context)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0D1B3E);
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black87;
    final cardColor = isDark ? colors.surfaceContainerHighest : Colors.white;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Pengaturan'.tr(context),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // 1. Notifikasi & Lansiran
          _buildSectionHeader('NOTIFIKASI & LANSIRAN'.tr(context), colors),
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
                SwitchListTile(
                  title: Text(
                    'Notifikasi Push (Aplikasi)'.tr(context),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Peringatan darurat via aplikasi'.tr(context),
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: Colors.orange,
                  value: _pushNotifications,
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark
                      ? Colors.grey.withValues(alpha: 0.2)
                      : Colors.grey.shade200,
                ),
                SwitchListTile(
                  title: Text(
                    'Lansiran SMS'.tr(context),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Kirim pesan SMS jika tidak ada koneksi internet'.tr(
                      context,
                    ),
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: Colors.orange,
                  value: _smsAlerts,
                  onChanged: (val) => setState(() => _smsAlerts = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Privasi & Lokasi
          _buildSectionHeader('PRIVASI & LOKASI'.tr(context), colors),
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
                SwitchListTile(
                  title: Text(
                    'Akses Lokasi Latar Belakang'.tr(context),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Sangat disarankan untuk evakuasi cepat'.tr(context),
                    style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  activeThumbColor: Colors.orange,
                  value: _locationTracking,
                  onChanged: _onLocationToggle,
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
                  title: Text(
                    'Izin Akses Kamera & Galeri'.tr(context),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _onCameraGalleryTap,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Tampilan & Aksesibilitas
          _buildSectionHeader('TAMPILAN & AKSESIBILITAS'.tr(context), colors),
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
                  title: Text(
                    'Bahasa'.tr(context),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _language,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _showLanguagePicker(context, cardColor),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Akun & Keamanan
          _buildSectionHeader('AKUN & KEAMANAN'.tr(context), colors),
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
                  leading: const Icon(Icons.lock_outline, color: Colors.grey),
                  title: Text(
                    'Ubah Kata Sandi'.tr(context),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    final email = UserModel.currentUser.value.email;
                    if (email.isEmpty) return;

                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    // Tampilkan loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) =>
                          const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      await AuthService.forgotPassword(email);
                      if (!mounted) return;
                      navigator.pop(); // Tutup loading

                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => ResetPasswordScreen(email: email),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      navigator.pop(); // Tutup loading
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
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
                  leading: const Icon(
                    Icons.shield_outlined,
                    color: Colors.grey,
                  ),
                  title: Text(
                    'Autentikasi Dua Langkah (2FA)'.tr(context),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    'Nonaktif'.tr(context),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () =>
                      _showComingSoonDialog('Autentikasi Dua Langkah (2FA)'),
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
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(
                    'Hapus Akun'.tr(context),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: cardColor,
                        title: Text('Hapus Akun?'.tr(context)),
                        content: Text(
                          'Tindakan ini tidak dapat dibatalkan. Seluruh riwayat donasi darah, poin relawan, dan rekam medis darurat akan dihapus permanen.'
                              .tr(context),
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
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Hapus Permanen'.tr(context)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: colors.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, Color cardColor) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih Bahasa'.tr(context),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._availableLanguages.map((language) {
                  final isSelected = _language == language;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      language == 'Bahasa Indonesia'
                          ? language.tr(context)
                          : language,
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.orange)
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
                    onTap: () async {
                      setState(() => _language = language);
                      final locale = language == 'English'
                          ? AppLocalization.localeEn
                          : AppLocalization.localeId;
                      SiagaKitaApp.localeNotifier.value = locale;

                      // Simpan preferensi
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'language_code',
                        locale.languageCode,
                      );

                      if (context.mounted) Navigator.pop(sheetContext);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
