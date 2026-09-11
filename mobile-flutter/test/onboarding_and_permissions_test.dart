import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siagakita/features/onboarding/presentation/onboarding_screen.dart';
import 'package:siagakita/features/permissions/presentation/permission_primer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'checkPermissionStatus') {
              return 1; // PermissionStatus.granted (enum index 1)
            }
            return 1;
          },
        );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'isLocationServiceEnabled') {
              return true;
            }
            if (methodCall.method == 'checkPermission') {
              return 3; // LocationPermission.always / whileInUse
            }
            return true;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/geolocator'),
          null,
        );
  });

  group('Onboarding & FTUE State Tests', () {
    test(
      'Initial state has_completed_onboarding is false by default',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final hasCompleted = prefs.getBool('has_completed_onboarding') ?? false;
        expect(hasCompleted, isFalse);
      },
    );

    test('has_completed_onboarding can be persisted as true', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);

      final hasCompleted = prefs.getBool('has_completed_onboarding') ?? false;
      expect(hasCompleted, isTrue);
    });
  });

  group('OnboardingScreen Widget Tests (ID Locale)', () {
    testWidgets('Renders first slide with title and controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('id'),
          supportedLocales: [Locale('id'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('RESPONS CEPAT'), findsOneWidget);
      expect(find.text('SOS Darurat Seketika'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
    });

    testWidgets('Tapping Lanjut navigates to second slide', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('id'),
          supportedLocales: [Locale('id'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('KOMUNITAS SIAGA'), findsOneWidget);
      expect(find.text('Jaringan Relawan & Instansi'), findsOneWidget);
    });
  });

  group('OnboardingScreen Widget Tests (EN Locale)', () {
    testWidgets('Renders first slide in English', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          supportedLocales: [Locale('id'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('FAST RESPONSE'), findsOneWidget);
      expect(find.text('Instant Emergency SOS'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('PermissionPrimerScreen Widget Tests', () {
    testWidgets('Renders cards after loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('id'),
          supportedLocales: [Locale('id'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PermissionPrimerScreen(
            target: PermissionPrimerTarget.returnOnly,
          ),
        ),
      );
      // Pump frames to allow async refresh to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Izin Aplikasi SiagaKita'), findsOneWidget);
      expect(find.text('Lokasi & GPS Presisi'), findsOneWidget);
      expect(find.text('Akses Mikrofon'), findsOneWidget);
      expect(find.text('Notifikasi Peringatan'), findsOneWidget);
      expect(find.text('Kamera Foto'), findsOneWidget);
      expect(find.text('Wajib'), findsOneWidget);
      expect(find.text('Lanjutkan ke Aplikasi'), findsOneWidget);
    });
  });
}
