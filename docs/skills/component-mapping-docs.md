# Component Mapping — Developer Guide

This document explains how to use the `component-mapping` skill and maintain [`docs/COMPONENT_MAPPING.md`](../COMPONENT_MAPPING.md) to guarantee **Multi-Client API Contract Parity (Rule A)** across SiagaKita's frontend applications and Go backend.

---

## The Architecture Matrix

SiagaKita runs two frontend clients against one Go Fiber backend:
- **`mobile-flutter`**: Dedicated to Citizens and Field Volunteers.
- **`windows_console_flutter`**: Dedicated to Agency Dispatchers and System Superadmins.

To prevent client contract drift, every feature must be registered in the central matrix:

```markdown
| Domain / Feature | Mobile Screen / Service | Desktop Console Screen / Service | Go Fiber Route & Handler | DB Table & Query | State, WS & Security |
```

---

## When to Update the Matrix

Update `docs/COMPONENT_MAPPING.md` whenever you:
1. Add or modify an HTTP route in `backend-go/internal/domain/`.
2. Add a new Flutter screen or service in `mobile-flutter` or `windows_console_flutter`.
3. Introduce a new WebSocket broadcast event or change an idempotency requirement (`X-Idempotency-Key`).
4. Modify database schemas or queries impacting client DTOs.
