# Incubyte HR — API

Rails 8.1 API-only backend for the Incubyte HR demo. The React frontend lives in the sibling
repository `../incubyte-FE`. Built through story S11c; later stories are in
[`docs/future-plans.md`](docs/future-plans.md).

## What it does

- Sign-in with short-lived JWTs and rotating refresh cookies; HR, manager and employee roles.
- Employee records, reporting hierarchy, org chart, self-service profile and directory.
- Excel imports: employees (create and update modes) and overnight leave, run as background jobs.
- Monthly payroll: draft calculation, generation, XLSX export, paid status.
- Reports and dashboards (headcount, joiners, leave, payroll, trends) with XLSX export.
- NL-to-SQL assistant: plain-English questions answered from each user's permitted data.

Docs: [`docs/README.md`](docs/README.md) (requirements, stories, test plan, API, architecture,
trade-offs, performance).

## Run the demo with Docker (recommended)

Requirements: Docker with Compose, both repositories side by side, and `config/master.key`
(credentials hold the JWT secret, the default password for imported employees, and the OpenRouter key).

```text
work/
├── incubyte/      # this repo (docker-compose.yml lives here)
└── incubyte-FE/   # frontend repo
```

```bash
docker compose up --build
```

| Service | What runs | URL |
|---|---|---|
| `fe` | Vite dev server (proxies `/api` to `web`) | http://localhost:5173 |
| `web` | Rails API, development mode (`db:prepare` creates and seeds the database) | http://localhost:3000 |
| `jobs` | Solid Queue worker (`bin/jobs`) for imports and payroll | — |
| `db` | PostgreSQL 18 | — |
| `mailhog` | Development mail catcher | http://localhost:8025 |

Both repositories are mounted into the containers, so code changes apply without rebuilding.
Optional: set `ASSISTANT_MODEL=<openrouter model>` in a `.env` file next to `docker-compose.yml`.

### Demo walkthrough

1. Generate the demo workbook (10,000 seeded employees plus the demo accounts EMP101–EMP107):
   ```bash
   docker compose exec web bin/rails "demo:employee_workbook[10000]"   # writes tmp/demo/employees_10000.xlsx
   ```
2. Sign in at http://localhost:5173 as `hr@demo.test` / `Demo@1234`.
3. Open **Employee import**, choose **Create employees**, upload `tmp/demo/employees_10000.xlsx`. The seed already
   provides everything it needs (roles, leave types, the five departments, demo users), so it completes with no
   row errors in about 20 seconds.
4. Optionally seed two months of leave: `docker compose exec web bin/rails demo:seed_leave`.
5. Explore the dashboard, org chart, payroll, reports and the **Assistant** (needs the OpenRouter key).
   Other demo logins: `meera@`, `arjun@` (managers), `priya@` (employee), all `@demo.test` with `Demo@1234`.

To start the demo again from an empty database: `docker compose down -v && docker compose up --build`.
Re-uploading the same workbook into a database that already has those employees reports every row as
"already exists" — that is the duplicate protection, not a failure.

## Run locally without Docker

Requirements: Ruby 3.4.1, PostgreSQL 18, Node.js 24, and optionally Mailhog (SMTP 1025, UI 8025).

```bash
bin/rails db:prepare     # creates the development and queue databases and loads db/seeds.rb
bin/rails server         # API on http://localhost:3000
bin/jobs                 # background worker (logs go to log/development.log)
cd ../incubyte-FE && npm install && npm run dev   # http://localhost:5173
```

`bin/rails db:reset` drops, recreates and seeds the development database (all data is lost).

## Seed data

`db/seeds.rb` is idempotent and creates the two roles, the four leave types (Earned, Sick, Casual, Unpaid),
the five departments used by the demo workbook (ENG, FIN, HRM, SAL, OPS), and eight demo accounts.

## Tests and checks

```bash
bundle exec rspec   # full backend suite
bin/rubocop         # style
bin/brakeman -q     # security scan (one documented, intended warning in config/brakeman.ignore)
```

Frontend: `npm test`, `npm run typecheck`, `npm run lint` in `../incubyte-FE`.

## Configuration

| Item | Where |
|---|---|
| JWT secret, import default password, OpenRouter key | Rails credentials (`bin/rails credentials:edit`) |
| Assistant provider, model, limits | `config/assistant.yml` (`ASSISTANT_MODEL` overrides the model) |
| CORS origins | `FRONTEND_ORIGINS` (default `http://localhost:5173`) |
| Database host | `PGHOST` / `PGUSER` / `PGPASSWORD` (default local socket) |
