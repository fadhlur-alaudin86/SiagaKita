import 'package:flutter/material.dart';
import '../../core/localization/app_localization.dart';
import '../../core/services/connectivity_service.dart';
import 'home_screen.dart';
import 'guide_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import '../relawan/relawan_main_screen.dart';
import '../../core/models/user_model.dart';
import '../../core/services/user_service.dart';

class MainScreen extends StatefulWidget {
  final String accessToken;
  final String userId;

  const MainScreen({
    super.key,
    required this.accessToken,
    required this.userId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    // Jika offline, gunakan data sesi yang sudah di-cache — tidak perlu hit server
    if (!ConnectivityService.isOnline.value) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final user = await UserService.getProfile(widget.accessToken);
      if (mounted) UserModel.currentUser.value = user;
    } catch (e) {
      // Gagal fetch profil saat online → tetap pakai data lokal
      debugPrint('[MainScreen] Gagal fetch profil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel>(
      valueListenable: UserModel.currentUser,
      builder: (context, user, child) {
        final isRelawan =
            user.volunteerStatus == 'approved' || user.role == UserRole.relawan;

        final List<Widget> screens = [
          HomeScreen(
            accessToken: widget.accessToken,
            userId: widget.userId,
            isSOSBanned: user.isSOSBanned,
          ),
          const GuideScreen(),
          if (isRelawan) RelawanMainScreen(accessToken: widget.accessToken),
          MapScreen(accessToken: widget.accessToken),
          ProfileScreen(accessToken: widget.accessToken),
        ];


        final List<BottomNavigationBarItem> navItems = [
          BottomNavigationBarItem(
            icon: const Icon(Icons.shield_outlined),
            activeIcon: const Icon(Icons.shield),
            label: 'Beranda'.tr(context),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_outlined),
            activeIcon: const Icon(Icons.menu_book),
            label: 'Panduan'.tr(context),
          ),
          if (isRelawan)
            BottomNavigationBarItem(
              icon: const Icon(Icons.radar_outlined),
              activeIcon: const Icon(Icons.radar),
              label: 'Operasi'.tr(context),
            ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            activeIcon: const Icon(Icons.map),
            label: 'Map'.tr(context),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: 'Profil'.tr(context),
          ),
        ];

        // Mencegah error jika role berubah dan currentIndex di luar batas
        if (_currentIndex >= screens.length) {
          _currentIndex = 0;
        }

        return Scaffold(
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: navItems,
            ),
          ),
        );
      },
    );
  }
}
