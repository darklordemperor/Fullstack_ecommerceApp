# Agent Guide

## Project Shape

This project is split into two root-level subprojects:

- `backend/`: Go 1.23, Gin, MongoDB driver v2, JWT v5, bcrypt.
- `frontend/`: Flutter, Riverpod, Dio, GoRouter, secure token storage, image picker, permission handler.

Keep backend routes under `/api`. Successful responses should use:

```json
{ "data": "...", "message": "..." }
```

Failures should use:

```json
{ "error": "..." }
```

Flutter API calls must go through `DioClient` and the platform-aware base URL in `frontend/lib/core/constants/api_constants.dart`.

## Platform URLs

- Android emulator uses `http://10.0.2.2:8080/api`.
- Flutter web, desktop, and iOS simulator use `http://localhost:8080/api`.
- Physical devices need the computer LAN IP.
- Flutter web admin is expected to run on `http://localhost:8082`.

Backend CORS must allow `Authorization` for web admin/client requests from `localhost:8082`.

## Auth, Roles, and Routing

Registration requires:

- `name`
- `lastname`
- `age >= 18`
- `gender`
- `address`
- valid email
- `password`
- `confirm_password`

Passwords must match:

```text
^[a-z0-9]{8,}$
```

Roles are stored directly on the user document:

- Customer: `["customer"]`
- Seller: `["customer", "seller"]`
- Admin: `["admin"]`

Seller access requires both:

- role contains `seller`
- `seller_status == "approved"`

Admin access requires:

- role contains `admin`

Admin is a management-only role. Admin users should route to `/admin` and should not access shopping, seller, cart, checkout, or product detail routes.

Banned users cannot log in or perform protected actions.

Seeded accounts:

- `test@example.com` / `abc12345`: customer
- `seller@example.com` / `abc12345`: approved seller
- `admin@example.com` / `abc12345`: admin

## Product Rules

Product creation/editing must enforce both frontend and backend validation:

- name required
- description required
- price must be `> 0` and `<= 1,000,000`
- price input should allow at most 7 digits before the decimal and 2 decimal places
- stock must be `0-99`
- stock input should allow at most 2 digits
- at least one image is expected in the Flutter seller form

Images are currently stored as URL strings or data-image strings for demo simplicity. Use `AppProductImage` to render product/profile images because it handles both.

Before opening gallery/camera, use `ensureImagePermission`. It must not crash if a native permission plugin is unavailable.

## Checkout and Orders

Checkout is real now:

- `POST /api/cart/checkout` creates order records grouped by seller and clears the cart.
- `POST /api/cart/buy-now` creates a direct order for one product.
- Seller dashboard orders come from persisted order records.

Do not make checkout only clear the cart.

## Admin APIs

Admin-only endpoints:

- `GET /api/admin/stats`
- `GET /api/admin/users`
- `GET /api/admin/products`
- `PUT /api/admin/users/:id/ban`
- `DELETE /api/admin/products/:id`

Use `middleware.RequireRole("admin", userRepo)` for admin endpoints.

## Frontend State and UX

- Riverpod `authProvider` is the source of truth for current user state.
- Startup should bootstrap auth from secure token storage before routing to login/home/admin.
- Expired or invalid JWTs should clear token storage and show a friendly login message.
- User-facing screens should not display raw Dart/programming errors. Use `AppErrorState`, `AppEmptyState`, and log technical details.
- Common image rendering should use `AppProductImage`.
- Admin ban UI must clearly say `Ban user` or `Unban user`, with visible `Active`/`Banned` status.

## Performance Notes

Keep large lists lazy:

- Home products: `SliverGrid` with builder
- Cart: `ListView.builder`
- Seller products/orders: builder-based lists
- Admin users/products: builder-based lists

Avoid eager mapping to widgets for large collections unless the collection is known to be tiny.

## Testing

Backend:

```bash
cd backend
go test ./...
```

Frontend:

```bash
cd frontend
flutter analyze
flutter test
```

When native Flutter plugins change, do a full rebuild:

```bash
flutter clean
flutter pub get
flutter run
```
