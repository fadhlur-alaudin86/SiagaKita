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

- **HTTP** — Use `Dio` for all API calls.
- **Auth** — Include JWT tokens from `SessionService` on authenticated requests:
  ```dart
  final token = await SessionService.getToken();
  final response = await dio.get('/endpoint',
      options: Options(headers: {'Authorization': 'Bearer $token'}));
  ```
- **State Management** — Use `setState` for simple local state, `Provider` for state shared across widgets.
- **Error handling** — Always handle `DioException` and display user-friendly error messages.

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

## Standard 6 — Code Style & Conventional Commits

- **Dart format** — Always run `dart format .` before committing.
- **No magic numbers** — Use named constants or responsive utilities.
- **Comments** — Provide doc comments for every public method and complex business logic block.
- **Conventional Commits** — Format identical to backend. Scopes: `mobile` or `desktop`.
  ```
  feat(mobile): add offline SOS auto-sync on reconnect
  fix(desktop): resolve dispatch volunteer placeholder screen
  ```

## Standard 7 — Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| File | `snake_case.dart` | `dispatch_screen.dart` |
| Class | `PascalCase` | `DispatchScreen` |
| Variable | `camelCase` | `isOnline` |
| Constant | `camelCase` or `SCREAMING_SNAKE` | `kDefaultTimeout` |
| Widget | Suffix `Widget` | `SOSStatusWidget` |
| Screen | Suffix `Screen` | `HomeScreen` |
| Service | Suffix `Service` | `SessionService` |
