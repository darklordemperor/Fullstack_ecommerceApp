# Full-Stack E-Commerce App

This repository contains a complete two-part e-commerce project:

- `backend/`: Go, Gin, MongoDB, JWT authentication, bcrypt password hashing, customer cart APIs, seller application and seller dashboard APIs.
- `frontend/`: Flutter app using Riverpod, Dio, GoRouter, secure token storage, cached network images, and a Shopee-inspired color scheme.

## Prerequisites

- Go 1.23 or newer
- Flutter latest stable
- Docker and Docker Compose

## Run Backend and MongoDB

From the `ecommerce` folder:

```bash
docker-compose up --build
```

The backend listens on `http://localhost:8080` and all routes are prefixed with `/api`.

Backend environment defaults live in `backend/.env`:

```env
MONGO_URI=mongodb://mongo:27017
MONGO_DB=ecommerce
JWT_SECRET=supersecretkey
PORT=8080
```

## Run Flutter Locally

From the `ecommerce/frontend` folder:

```bash
flutter pub get
flutter run
```

The Android emulator base URL is configured in `lib/core/constants/api_constants.dart`:

```dart
const String baseUrl = 'http://10.0.2.2:8080/api';
```

For an iOS simulator, use `http://localhost:8080/api`. For a real device, replace the host with your computer's LAN IP address and make sure the device can reach that network.

## Default Test Credentials

Register a test customer in the app or by calling:

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","lastname":"Customer","age":25,"email":"test@example.com","password":"abc12345","confirm_password":"abc12345"}'
```

Then log in with:

- Email: `test@example.com`
- Password: `abc12345`

Passwords must match `^[a-z0-9]{8,}$`: lowercase letters and digits only, at least 8 characters.

## Seller Approval Flow

Every registered user starts as a customer. To become a seller:

1. Log in and call `POST /api/users/seller-apply` from the app's seller application screen.
2. Approve the application with the mock admin endpoint:

```bash
curl -X POST http://localhost:8080/api/users/seller-approve/<USER_ID> \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

After approval, the user's role includes `seller` and `seller_status` is `approved`, which unlocks product creation and the seller dashboard.
