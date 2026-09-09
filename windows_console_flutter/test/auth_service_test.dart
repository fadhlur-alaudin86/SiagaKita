import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:siagakita_console/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('updateTokens and token accessors correctly persist tokens', () async {
    await AuthService.updateTokens('access-token-123', 'refresh-token-456');

    final access = await AuthService.getAccessToken();
    final refresh = await AuthService.getRefreshToken();

    expect(access, equals('access-token-123'));
    expect(refresh, equals('refresh-token-456'));
  });

  test('restoreSession loads stored access and refresh tokens', () async {
    FlutterSecureStorage.setMockInitialValues({
      'console_access_token': 'acc-jwt-999',
      'console_refresh_token': 'ref-jwt-888',
      'console_role': 'admin',
      'console_name': 'Admin Siaga',
    });

    final session = await AuthService.restoreSession();
    expect(session, isNotNull);
    expect(session!.accessToken, equals('acc-jwt-999'));
    expect(session.refreshToken, equals('ref-jwt-888'));
    expect(session.role, equals('admin'));
    expect(session.fullName, equals('Admin Siaga'));
  });

  test('logout clears stored credentials', () async {
    await AuthService.updateTokens('access-token-123', 'refresh-token-456');
    await AuthService.logout();

    final access = await AuthService.getAccessToken();
    final refresh = await AuthService.getRefreshToken();

    expect(access, isNull);
    expect(refresh, isNull);
  });

  test('headers helper includes authorization and content-type', () {
    final h = AuthService.headers('test-token');
    expect(h['Authorization'], equals('Bearer test-token'));
    expect(h['Content-Type'], equals('application/json'));
    expect(h.containsKey('Accept-Language'), isTrue);
  });
}
