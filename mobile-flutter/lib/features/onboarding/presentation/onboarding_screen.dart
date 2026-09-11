// Purpose:
//   Provides the first-launch visual walkthrough onboarding flow for new users,
//   highlighting core SiagaKita capabilities (SOS, Volunteer Network, Family Radar)
//   with smart navigation routing.
//
// Data & Logic Flow:
//   1. Displays 3 visual swipeable slides using PageView.
//   2. Persists 'has_completed_onboarding = true' upon Skip or Completion.
//   3. Performs Smart Transition Check: queries LocationService permission.
//   4. Navigates to PermissionPrimerScreen if location is missing, or LoginScreen if granted.
//
// Key Components:
//   - OnboardingScreen: Stateful widget managing page transitions and local storage persistence.
//   - _OnboardingSlide: Data class defining visual slide assets, titles, and descriptions.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/location_service.dart';
import '../../auth/login_screen.dart';
import '../../permissions/presentation/permission_primer_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isNavigating = false;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.crisis_alert_rounded,
      iconColor: Color(0xFFFF4D4D),
      badgeText: 'RESPONS CEPAT',
      badgeColor: Color(0xFFFF4D4D),
      title: 'SOS Darurat Seketika',
      description:
          'Kirim sinyal bahaya seketika dalam hitungan detik dengan siaga countdown dan transmisi lokasi presisi ke pos komando.',
    ),
    _OnboardingSlide(
      icon: Icons.shield_outlined,
      iconColor: Color(0xFFFF7418),
      badgeText: 'KOMUNITAS SIAGA',
      badgeColor: Color(0xFFFF7418),
      title: 'Jaringan Relawan & Instansi',
      description:
          'Terhubung langsung dengan tim relawan terverifikasi serta armada instansi resmi (Damkar, Medis, Polisi) di sekitar Anda.',
    ),
    _OnboardingSlide(
      icon: Icons.family_restroom_rounded,
      iconColor: Color(0xFF18A3FF),
      badgeText: 'KESELAMATAN KELUARGA',
      badgeColor: Color(0xFF18A3FF),
      title: 'Zonasi & Perlindungan Keluarga',
      description:
          'Pantau radius aman keluarga tercinta secara real-time dan dapatkan notifikasi otomatis saat terjadi insiden darurat.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_isNavigating) return;
    _isNavigating = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (!mounted) return;

    // Smart Transition Check: periksa apakah izin lokasi sudah aktif
    final hasLocation = await LocationService.hasPermission();
    if (!mounted) return;

    if (!hasLocation) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const PermissionPrimerScreen(
            target: PermissionPrimerTarget.login,
          ),
        ),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBgColor = Color(0xFF0D1B3E);
    const Color cardColor = Color(0xFF162A5A);
    const Color primaryColor = Color(0xFFFF7418);

    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: darkBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Lewati'.tr(context),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (ctx, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Visual Illustration Box
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: slide.iconColor.withAlpha(50),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                            border: Border.all(
                              color: slide.iconColor.withAlpha(80),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              slide.icon,
                              size: 88,
                              color: slide.iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: slide.badgeColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: slide.badgeColor.withAlpha(100),
                            ),
                          ),
                          child: Text(
                            slide.badgeText.tr(ctx),
                            style: TextStyle(
                              color: slide.badgeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title
                        Text(
                          slide.title.tr(ctx),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Description
                        Text(
                          slide.description.tr(ctx),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                children: [
                  // Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: isActive ? 28 : 8,
                        decoration: BoxDecoration(
                          color: isActive ? primaryColor : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        (isLastPage ? 'Mulai Sekarang' : 'Lanjut').tr(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
}

class _OnboardingSlide {
  final IconData icon;
  final Color iconColor;
  final String badgeText;
  final Color badgeColor;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.iconColor,
    required this.badgeText,
    required this.badgeColor,
    required this.title,
    required this.description,
  });
}
