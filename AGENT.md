# Agent Guide

## Project Shape

This project is intentionally split into two subprojects:

- `backend/`: Go 1.23, Gin, MongoDB driver v2, JWT v5, bcrypt.
- `frontend/`: Flutter, Riverpod, Dio, GoRouter, secure token storage.

Keep backend routes under `/api`, preserve the response shape `{ "data": ..., "message": "..." }` for successes and `{ "error": "..." }` for failures, and keep Flutter API calls pointed at `lib/core/constants/api_constants.dart`.

## Validation and Auth Rules

- Registration requires `name`, `lastname`, `age >= 18`, valid email, `password`, and `confirm_password`.
- Passwords must match `^[a-z0-9]{8,}$`.
- New users always start with `role: ["customer"]`.
- Seller access requires both `role` containing `seller` and `seller_status == "approved"`.
- Seller upgrades must flow through `POST /api/users/seller-apply` and `POST /api/users/seller-approve/:id`.

## Testing

Run backend tests from `backend/`:

```bash
go test ./...
```

Run frontend tests from `frontend/`:

```bash
flutter pub get
flutter test
```

Current tests are designed to be fast unit/widget tests that do not need a live MongoDB instance or backend server. Add integration tests separately if a future change needs database or HTTP coverage.

## Local Run Commands

From the project root:

```bash
docker compose up --build
```

From `frontend/`:

```bash
flutter run
```

Use Android emulator base URL `http://10.0.2.2:8080/api`, iOS simulator base URL `http://localhost:8080/api`, and a LAN IP for physical devices.
