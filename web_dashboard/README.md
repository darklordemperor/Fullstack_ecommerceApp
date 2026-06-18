# Web Dashboard

Angular + Tailwind admin dashboard for the e-commerce backend.

## Run

Start backend and MongoDB first from the repo root:

```bash
docker compose up --build -d
```

Then run the dashboard:

```bash
cd web_dashboard
npm install
npm start
```

Dashboard URL:

```text
http://localhost:4200
```

Backend API:

```text
http://localhost:8080/api
```

Seeded admin login:

```text
admin@example.com
abc12345
```

## Checks

```bash
npm run build
npm test -- --watch=false
```
