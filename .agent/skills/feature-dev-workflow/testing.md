# Testing Conventions — SiagaKita

Testing standards for Go backend and Flutter. Sub-file of [SKILL.md](SKILL.md).

## Go — Backend Testing

### Setup

```bash
# Run all backend tests
cd backend-go && go test ./... -v -race -timeout 60s

# Run domain-specific tests
go test ./internal/domain/incident/... -v

# Run tests with coverage
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out
```

### Table-Driven Test Pattern

```go
func TestHandlerName(t *testing.T) {
    tests := []struct {
        name       string
        input      RequestStruct
        wantStatus int
        wantBody   string
    }{
        {
            name:       "success",
            input:      RequestStruct{Field: "valid"},
            wantStatus: 200,
            wantBody:   `"data"`,
        },
        {
            name:       "invalid input",
            input:      RequestStruct{},
            wantStatus: 400,
            wantBody:   `"error"`,
        },
        {
            name:       "empty result",
            input:      RequestStruct{Field: "nonexistent"},
            wantStatus: 200,
            wantBody:   `[]`,
        },
        {
            name:       "db error",
            input:      RequestStruct{Field: "trigger_error"},
            wantStatus: 500,
            wantBody:   `"error"`,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup Fiber test app
            app := fiber.New()
            // ... handler setup

            // Make request
            // Assert status + body
        })
    }
}
```

### Mandatory 4 Test Cases Per Handler

1. **Success case** — Valid input returns expected response and 200 OK.
2. **Empty result case** — Valid query with no matching records returns empty list `[]` and 200 OK.
3. **Invalid input case** — Malformed body or missing fields returns 400 Bad Request.
4. **DB error case** — Database failure/connection issue returns 500 Internal Server Error.

### Test Rules

- **Isolated** — No shared state between tests. Use in-memory DB or mocks.
- **Deterministic** — No dependency on unmocked `time.Now()` or random values.
- **Fast** — Execution takes < 1 second per file.
- **Race detector** — Always run with `-race` flag.

### Test File Naming

```
Path   : backend-go/internal/domain/<name>/<file>_test.go
Example: backend-go/internal/domain/incident/handler_test.go
```

## Flutter — Widget & Unit Testing

### Setup

```bash
# Run all mobile tests
cd mobile-flutter && flutter test

# Run specific test file
flutter test test/features/incident/dispatch_test.dart

# Run with coverage
flutter test --coverage
```

### Flutter Test Pattern

```dart
void main() {
  group('DispatchService', () {
    late DispatchService service;
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
      service = DispatchService(dio: mockDio);
    });

    test('fetchVolunteers returns list on success', () async {
      when(mockDio.get(any)).thenAnswer((_) async =>
          Response(data: [...], statusCode: 200, requestOptions: RequestOptions()));

      final result = await service.fetchVolunteers();
      expect(result, isNotEmpty);
    });

    test('fetchVolunteers throws on network error', () async {
      when(mockDio.get(any)).thenThrow(DioException(...));
      expect(() => service.fetchVolunteers(), throwsA(isA<Exception>()));
    });
  });
}
```

### Test File Naming (Flutter)

```
Path   : mobile-flutter/test/features/<name>/<file>_test.dart
Example: mobile-flutter/test/features/incident/dispatch_test.dart
```

## Test Documentation in Feature Log

After running tests, update the table in `docs/backlog/features/F-XXX-name.md`:

```markdown
## Test Cases

| Layer | Test Name | Scenario | Run Command | Last Run | Status |
|-------|-----------|----------|-------------|----------|--------|
| handler | TestDispatch/success | Dispatch succeeds | `go test ./internal/domain/incident/... -run TestDispatch/success` | 2026-08-08 | ✅ Pass |
| handler | TestDispatch/invalid_input | Invalid input | `go test ./internal/domain/incident/... -run TestDispatch/invalid_input` | 2026-08-08 | ✅ Pass |
| service | TestDispatchService | Service unit test | `flutter test test/features/incident/dispatch_test.dart` | 2026-08-08 | ✅ Pass |
```
