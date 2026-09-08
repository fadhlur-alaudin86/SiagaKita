import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siagakita/core/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('saveSession persists token in secure storage and metadata in prefs', () async {
    await SessionService.saveSession(
      token: 'jwt-secure-token-xyz',
      userId: 'user-uuid-123',
      email: 'relawan@siagakita.com',
      role: 'volunteer',
      name: 'Budi Santoso',
    );

    final session = await SessionService.loadSession();
    expect(session, isNotNull);
    expect(session!.token, equals('jwt-secure-token-xyz'));
    expect(session.userId, equals('user-uuid-123'));
    expect(session.email, equals('relawan@siagakita.com'));
    expect(session.role, equals('volunteer'));
    expect(session.name, equals('Budi Santoso'));

    final token = await SessionService.getToken();
    expect(token, equals('jwt-secure-token-xyz'));
  });

  test('loadSession migrates legacy token from SharedPreferences to secure storage', () async {
    // Simulate legacy session in plain SharedPreferences
    SharedPreferences.setMockInitialValues({
      'session_token': 'legacy-plain-token-abc',
      'session_user_id': 'user-uuid-legacy',
      'session_email': 'warga@siagakita.com',
      'session_role': 'civilian',
      'session_name': 'Warga Siaga',
    });
    FlutterSecureStorage.setMockInitialValues({});

    final session = await SessionService.loadSession();
    expect(session, isNotNull);
    expect(session!.token, equals('legacy-plain-token-abc'));

    // Token should now be available from secure storage
    final secureToken = await SessionService.getToken();
    expect(secureToken, equals('legacy-plain-token-abc'));

    // Legacy token key should be cleaned from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_token'), isNull);
  });

  test('clearSession removes all session data from both storages', () async {
    await SessionService.saveSession(
      token: 'temp-token',
      userId: 'temp-user',
      email: 'temp@siagakita.com',
      role: 'civilian',
    );

    await SessionService.clearSession();
    final session = await SessionService.loadSession();
    expect(session, isNull);

    final token = await SessionService.getToken();
    expect(token, isNull);
  });

  test('updateName updates stored user name', () async {
    await SessionService.saveSession(
      token: 'temp-token',
      userId: 'temp-user',
      email: 'temp@siagakita.com',
      role: 'civilian',
      name: 'Old Name',
    );

    await SessionService.updateName('New Name');
    final session = await SessionService.loadSession();
    expect(session?.name, equals('New Name'));
  });
}
