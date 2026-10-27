# AGENTS.md

Instructions for AI agents working in this repository. Follow them literally. If any instruction
conflicts with a direct request from the user, ask before proceeding.

## 1. Repository context

| Item | Value |
|---|---|
| Application | Rails 8.1.4 API-only backend (`config.api_only = true`) with PostgreSQL 18.6 |
| Frontend | Separate React repo at `../incubyte-FE` (Vite + TypeScript; shadcn/ui + Tailwind CSS; Vitest + React Testing Library) |
| Current state | S01–S06 and S08–S10 complete (auth, HR settings, employee records, hierarchy, self-service and directory, leave Excel upload with balances, monthly payroll run, payroll Excel export and paid status, reports and dashboards); S07 cut; S11 next; smoke pack deferred to the end; RSpec, Mailhog, and Solid Queue (run `bin/jobs` in development) configured |
| Product docs | `docs/requirements.md`, `docs/product-stories.md`, `docs/test-plan.md`, `docs/README.md` |
| Story order | S01 → S19, strictly sequential (S07 cut; S19 change history deferred from S05) |
| Prompt log | `prompts/prompt-log.md` |

Read the requirements and the next story before writing any code. The stories define the
acceptance criteria and test cases; do not invent scope.

## 2. Prompt logging (mandatory, every turn)

Every user prompt must be logged, including follow-ups, corrections, and one-line requests.

- **Where:** append to `prompts/prompt-log.md`.
- **When:** at the start of the turn, before implementation. Update `Notes:` when the work is done.
- **How:** add the current date as a `## YYYY-MM-DD` heading if it does not exist, then:

```markdown
### <short title>

> <the user's prompt, verbatim>

Notes: <what changed, files touched, tests run>
```

- Log user messages only; do not log system updates, tool output, or environment notices.
- Never rewrite, reorder, or delete existing log entries.
- If the prompt is a correction, log it as its own entry and state what it corrects.
- Documentation-only turns are logged too.

## 3. Required development workflow

1. Read `docs/requirements.md` and the current story in `docs/product-stories.md`.
2. Confirm the story, the acceptance criteria in scope, and the files you expect to touch in both
   the backend and `../incubyte-FE`.
3. Ask any blocking questions (§7) before writing code.
4. Work in TDD order (§4) inside a 50-line review chunk (§5).
5. Stop at the checkpoint and wait for explicit approval before continuing.
6. Update the prompt log notes and any affected documentation.

One story at a time. Each story includes its backend slice and its React slice; the story is not
complete until both are delivered and tested. Do not start the next story or an unrelated refactor
without approval.

## 4. TDD with RSpec and Vitest (mandatory)

RSpec is the test framework. Before the first feature, add `rspec-rails`, `factory_bot_rails`,
`faker`, `jwt`, `pundit`, `bcrypt`, and `rack-cors`, and remove the Minitest `test/` directory.
Authentication uses JWT; authorisation uses Pundit. This setup is a reviewed chunk (§5). Do not add
other gems without approval.

**Required loop for every behaviour**

1. Write one failing spec for the next acceptance criterion.
2. Run it and confirm it fails for the intended reason (red).
3. Write the minimum production code to pass (green).
4. Refactor without changing behaviour; re-run.
5. Run the full suite before reporting a checkpoint.

**Rules**

- No production code without a failing spec, except generated framework files and pure
  configuration, which still require a smoke check.
- Before writing the specs for a chunk, list each planned test as a one-line description in the
  chunk plan. Specs and factories are excluded from the 50-line count; the descriptions are what the
  user reviews.
- Prefer request specs for endpoints, model specs for validations/associations, service specs for
  workflows, job specs for background work, and system specs only where a browser flow is essential.
  Frontend behaviour follows the same loop in `../incubyte-FE` using Vitest + React Testing Library:
  a failing component test first, then the component, then green.
- Test behaviour and public contracts, not private methods.
- Use FactoryBot factories with traits; avoid shared mutable state and fixtures for domain data.
- Use `travel_to` for time-dependent behaviour; never `sleep` to wait for state.
- Use ActionMailer test delivery for email assertions; Mailhog is for manual inspection.
- Cover happy path, negative, edge, and permission cases from the story's test table.
- Add a query-count spec where a list or report could produce an N+1.
- Add a concurrency or database-constraint spec where the story involves uniqueness, balances,
  approvals, imports, or payroll generation.

## 5. 50-line chunks and review gate (mandatory)

Implementation is delivered in reviewable chunks. The user reviews after every chunk; the next
chunk starts only after explicit approval.

**Counting rule**

- Count every hand-written **production** line added or changed under `app/`, `lib/`, `db/`,
  `config/`, and the React source in `../incubyte-FE/src/`.
- Exclude specs, factories, test helpers, generated boilerplate, lockfiles, documentation,
  formatting-only churn, and generated migrations.
- 50 lines is a maximum, not a target. Split earlier by behaviour if that is cleaner.
- If a chunk needs more than 50 production lines, split the design (smaller service, query, or
  component) rather than exceeding the limit.

**Checkpoint protocol**

1. Before starting, state the chunk plan: story, acceptance criteria, production files, and each
   planned test as a one-line description.
2. Work red → green → refactor within the chunk.
3. Stop when the next change would exceed 50 production lines, or when the behavioural slice is
   complete.
4. Leave both repositories green: backend specs and RuboCop pass; frontend tests, typecheck, and
   lint pass.
5. Report using the format below.
6. Wait for `approved`, `continue`, or `next`. Do not continue proactively, and do not write the
   next chunk while waiting.
7. On review feedback, change only that chunk and re-report.

**Checkpoint report format**

```text
Chunk: S01-2 (chunk 2 of the story)
Story: S01 — Sign-in and role-based access
Acceptance: AC-03, AC-04
Tests planned:
  - rejects a request without a token
  - rejects an expired token
  - allows an employee to read their own profile
Tests: 3 examples, 0 failures (red phase: 3 failing before implementation)
Frontend tests: 2 passed
Changed: app/controllers/api/v1/... (+34/-2); ../incubyte-FE/src/... (+18/-1)
Production lines: 48 of 50
N+1 / concurrency: none affected (or explain the check performed)
Next: token refresh (AC-05), approx. 20 lines
Awaiting: approval to continue
```

- Commit once per accepted story in **both** repositories, after the chunk reviews and story
  sign-off. The regression smoke pack runs once at the end, not per story. Never commit mid-story or while a chunk awaits review. Include
  the story ID in both commit messages.
- Do not bundle a second story into a checkpoint.
- A chunk includes its specs and implementation together, but only production lines count toward
  the 50-line limit.

## 6. Engineering standards

**Code style**

- Self-descriptive names: prefer `approve_leave_request` over `process`, `eligible_for_payroll?`
  over `check`.
- Minimal comments. Comment only non-obvious intent or trade-offs (why), never restate the code
  (what). No commented-out code, no TODOs without an owner and a linked issue.
- Small methods, small classes, clear boundaries. Thin controllers; no business logic in callbacks
  or controllers.
- Follow the existing Rails conventions and RuboCop configuration. Run `bin/rubocop` on changes.

**DRY without premature abstraction**

- Extract service objects for multi-step workflows (leave approval, payroll generation, candidate
  conversion), query objects for reporting, and form objects for complex input.
- Do not create an abstraction for a single use. Duplication is acceptable until the third case.
- Keep domain rules in one place; validations belong in models and, where integrity matters, in the
  database.

**Database and N+1**

- Add indexes for foreign keys, lookups, and unique constraints.
- Use `includes`/`preload` for associations rendered in lists; use `strict_loading` in development
  to catch lazy loads.
- Never load 10,000 rows into memory for a page or export; paginate and use `find_each`/`in_batches`.
- Use aggregate queries for dashboards, not Ruby-side counting over loaded records.
- Write reversible migrations with safe defaults; never destructive changes without approval.

**Concurrency and race conditions**

- Enforce uniqueness in the database (unique indexes), not only with model validations.
- Wrap state transitions in transactions and lock the relevant row (`with_lock`, `lock!`,
  `SELECT ... FOR UPDATE`).
- Treat approvals, leave balances, payroll runs, and imports as state machines: re-check the state
  inside the transaction.
- Make imports and exports idempotent; use unique keys and upserts for leave and
  employee/candidate imports.
- Handle `ActiveRecord::RecordNotUnique` and deadlocks with a bounded retry, never a blind loop.
- Use append-only ledger entries for leave balances; never recalculate history destructively.
- Design background jobs to be idempotent and safe to retry.
- Where the story allows it, add a multi-threaded spec or a database-constraint spec proving the
  invariant holds.

**Security and privacy**

- Use Pundit policies for every endpoint and keep record scoping in policy scopes (manager subtree,
  candidate self, HR). Do not authorise by checking IDs after loading a record.
- JWT rules: sign with a secret from Rails credentials, pin the algorithm, set short expiry, validate
  `exp`/`iss`/`aud`, and never place PII or secrets in claims. Support logout/revocation and reject
  tokens for deactivated employees.
- Strong parameters everywhere; never mass-assign role, status, salary, or bank fields.
- Salary, CTC, bank, and candidate data follow the visibility rules in the requirements.
- No secrets in code or specs; use credentials or environment variables.
- Never log tokens, passwords, or full bank numbers. Filter sensitive parameters from logs. Store
  passwords only as hashes.
- Validate uploads by type and size and serve them only after authorization.

**Errors and observability**

- Use domain-specific errors; translate them to appropriate HTTP statuses at the boundary.
- Keep user-facing messages safe; log the technical detail with context.
- Record audit entries for approvals, compensation, bank, status, and hierarchy changes.
- Never rescue `Exception`; rescue the narrowest class and re-raise when unsure.

**Background work and files**

- Jobs must be idempotent, small, and retry-safe.
- Excel/CSV processing must stream or batch, report row-level errors, and never partially commit
  silently.
- Email is sent through Mailhog on localhost; do not add an external provider.

**API and React frontend**

- The backend remains API-only. The frontend is the React SPA in the sibling `../incubyte-FE`
  repository (Vite + TypeScript). Do not add Rails views or a second frontend.
- Use shadcn/ui with Tailwind CSS for the React UI; do not add another component library.
- Routes live under `/api/v1`. Define and document the JSON contract for each story before
  implementing it. Keep responses stable.
- Errors use `{ "error": { "code", "message", "details" } }`; lists use
  `{ "data": [...], "meta": { "page", "per_page", "total" } }`. Use appropriate HTTP status codes.
- Configure CORS as an explicit allowlist (`http://localhost:5173` in development); never combine
  wildcard origins with credentials.
- Authentication uses the `jwt` gem with `has_secure_password`. Send short-lived access tokens and
  refresh tokens as `Authorization: Bearer`; revoke via a token version. Enforce the 8-hour
  inactivity policy in the refresh flow.
- Authorisation is enforced on the API with Pundit; the React app must not be trusted to enforce
  visibility.

## 7. No unilateral decisions

Ask before doing any of the following:

- Adding or removing gems, libraries, or services.
- Changing the database schema, indexes, or data model beyond the approved story.
- Choosing an authentication, authorization, background-job, or UI approach.
- Changing the public API contract or the requirements/story scope.
- Deleting files, rewriting history, force-pushing, or changing CI.
- Committing outside the agreed per-story cadence, or pushing.
- Interpreting an ambiguous acceptance criterion in a way that changes behaviour.

**How to ask**

- Number the questions.
- Give 2–3 concrete options with trade-offs.
- State a recommendation and the impact of each option.
- Stop and wait. Do not implement while a blocking question is open.

## 8. Confirmed decisions and remaining gaps

**Confirmed**

| Topic | Decision |
|---|---|
| Frontend | Separate repo `../incubyte-FE`: Vite + TypeScript; shadcn/ui + Tailwind CSS; Vitest + React Testing Library; Rails stays API-only |
| Tests | RSpec + FactoryBot + Faker; remove the Minitest `test/` directory |
| Authentication | `jwt` gem + `has_secure_password`; Bearer access + refresh tokens; token-version revocation; 8-hour inactivity policy |
| Token lifetimes | 15-minute access token; rotating HttpOnly refresh cookie; 8-hour inactivity window (1 minute in tests) |
| S01 frontend | Sign-in, session restore, protected dashboard route, role-aware landing, logout, and HR-only settings access |
| Authorisation | Pundit policies with scoped queries |
| API | `/api/v1`; error envelope; offset pagination; CORS `http://localhost:5173` in development |
| Email | Mailhog on localhost (SMTP 1025, UI 8025) |
| 50-line count | Production code only; specs and factories excluded; one-line test descriptions before writing specs |
| Commits | One per accepted story in both repos, after story sign-off |
| Input fixtures | Leave Excel built in specs (S06); employee Excel expected for bulk employee import |

**Still to confirm**

- **Frontend scope per story:** which screens are in the demo for each remaining story, since the
  stories describe product behaviour rather than UI detail.

## 9. Definition of done

**Per chunk**

- Planned tests listed as one-line descriptions before the specs were written.
- Failing spec written first, now green.
- Relevant backend specs and the full suite pass.
- Frontend tests, `npm run typecheck`, and `npm run lint` pass in `../incubyte-FE`.
- `bin/rubocop` clean.
- Pundit authorisation applied; JWT handling follows §6.
- API contract documented for any new or changed endpoint.
- No new N+1; indexes/constraints added where needed.
- No secrets or debug code.
- Checkpoint report delivered and approval requested.

**Per story**

- Every acceptance criterion demonstrated.
- All story test cases pass, including negative and permission cases.
- React screens for the story delivered and tested with Vitest + React Testing Library.
- API documentation updated for new or changed endpoints.
- Full automated suites pass (the regression smoke pack from `docs/test-plan.md` runs once at the end).
- Documentation updated if behaviour or contracts changed.
- Prompt log notes updated.
- One commit in each repository after sign-off, both referencing the story ID.

## 10. Commands

```bash
bin/rails server                  # run the API
bundle exec rspec                 # full backend suite (after RSpec setup)
bundle exec rspec spec/requests   # targeted backend suite
bin/rubocop                       # style
bin/brakeman -q                   # security scan
bin/rails db:prepare              # migrations and databases
~/.local/pgsql/pg.sh start        # local PostgreSQL (user-level install)
~/.local/pgsql/pg.sh status

# Mailhog when installed: SMTP localhost:1025, web UI http://localhost:8025

# Frontend (sibling repo)
cd ../incubyte-FE
npm run dev         # http://localhost:5173
npm test            # Vitest + React Testing Library
npm run typecheck
npm run lint
```
