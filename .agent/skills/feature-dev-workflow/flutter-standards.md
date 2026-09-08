# Flutter Development Standards — SiagaKita

Flutter/Dart standards for mobile-flutter and windows_console_flutter. Sub-file of [SKILL.md](SKILL.md).

## Standard 1 — File Structure

```
mobile-flutter/lib/
  core/
    utils/
      responsive.dart          ← MANDATORY for UI sizing
    services/
      session_service.dart     ← Login persistence, logout cleanup
      connectivity_service.dart ← Real-time online/offline detection
      offline_service.dart      ← Offline data (pending SOS, cooldown)
  features/
    <feature_name>/
      <name>_screen.dart       ← Main screen
      <name>_widget.dart       ← Reusable widgets (if needed)
      <name>_service.dart      ← API calls + local logic
```

```
windows_console_flutter/lib/
  features/
    <feature_name>/
      <name>_screen.dart
      <name>_widget.dart
```

## Standard 2 — Responsive Utilities

- **MANDATORY**: Use `responsive.dart` for all UI sizing:
  ```dart
  import 'package:mobile_flutter/core/utils/responsive.dart';
  // Use rs(16) for font size, rw(100) for width, rh(50) for height
  ```
- Do not hardcode pixel values without using the responsive utility.
- Test across various screen dimensions.

## Standard 3 — HTTP & State Management

- **HTTP** — Use `Dio` for all API calls with explicit `connectTimeout` (e.g. 5s) and `receiveTimeout` (e.g. 10s).
- **Secure Token Storage** — Authentication tokens (JWT, Refresh Token) must be stored in secure hardware-backed storage (`flutter_secure_storage` via Keychain on iOS and EncryptedSharedPreferences on Android). Non-sensitive user preferences (e.g. theme, onboarding flags) may use `SharedPreferences`.
- **Token Refresh Resilience** — Implement a Dio Interceptor for 401 handling with a mutex / one-time retry flag to prevent cascading infinite refresh loops.
- **State Management** — Use `setState` for simple local state, `Provider` for state shared across widgets.
- **Error handling** — Always handle `DioException` and display user-friendly error messages (never dump raw stack trace or raw JSON to UI).

## Standard 4 — Offline Resilience & Performance

- Use `ConnectivityService.isOnline` for real-time connectivity status.
- Critical operations (SOS) must support offline fallback via `OfflineService`.
- Auto-sync pending data when connection is restored.

## Standard 5 — Performance Optimization

- Wrap heavy list and chart widgets in `RepaintBoundary`:
  ```dart
  RepaintBoundary(
    child: HeavyListWidget(),
  )
  ```
- Use `Isolate` for parsing large JSON payloads.
- Lazy load images and non-critical data.

## Standard 6 — BuildContext Async Safety (ECC Pattern)

- **Always Check `context.mounted`**: Never use `BuildContext` (for `Navigator`, `ScaffoldMessenger`, or `Theme.of`) across an `await` boundary without checking `context.mounted`:
  ```dart
  // ✅ GOOD: Safe navigation after async call
  final success = await authService.login(email, password);
  if (!context.mounted) return;
  Navigator.pushReplacementNamed(context, '/dashboard');

  // ❌ BAD: Can crash or cause memory leak if user navigated away
  await authService.login(email, password);
  Navigator.pushReplacementNamed(context, '/dashboard');
  ```

## Standard 7 — Widget Clean Architecture

- **Class-Based Widgets**: Always extract reusable or stateful UI components into standalone `StatelessWidget` or `StatefulWidget` classes rather than private helper methods like `Widget _buildCard()`. Standalone classes enable Flutter's element tree reuse, avoid unnecessary rebuilds, and support `const` constructors.
- **Const Propagation**: Use `const` constructors wherever possible to reduce GC pressure and widget tree rebuild cost.

## Standard 8 — Code Style & Conventional Commits

- **Dart format** — Always run `dart format .` before committing.
- **No magic numbers** — Use named constants or responsive utilities.
- **Comments** — Provide doc comments for every public method and complex business logic block.
- **Conventional Commits** — Format identical to backend. Scopes: `mobile` or `desktop`.
  ```
  feat(mobile): add offline SOS auto-sync on reconnect
  fix(desktop): resolve dispatch volunteer placeholder screen
  ```

## Standard 9 — Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| File | `snake_case.dart` | `dispatch_screen.dart` |
| Class | `PascalCase` | `DispatchScreen` |
| Variable | `camelCase` | `isOnline` |
| Constant | `camelCase` or `SCREAMING_SNAKE` | `kDefaultTimeout` |
| Widget | Suffix `Widget` | `SOSStatusWidget` |
| Screen | Suffix `Screen` | `HomeScreen` |
| Service | Suffix `Service` | `SessionService` |
