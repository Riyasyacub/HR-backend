# Trade-offs

Each entry records the decision, what it costs, and why it won over the alternatives. Decisions were
made with the product owner during the build (see `prompts/prompt-log.md` for the conversation).

## Platform

| Decision | Chosen | Alternatives | Why / cost |
|---|---|---|---|
| Application shape | Rails API-only + separate React SPA | Rails views (Hotwire); one repo | Clean JSON contract, frontend can evolve independently. Cost: two repos, CORS, two test suites, duplicated types. |
| Background jobs | Solid Queue (PostgreSQL-backed) | Sidekiq + Redis | No extra service to run; jobs share the database's durability. Cost: lower throughput than Redis, and a separate queue database; adequate for imports and payroll at 10k scale. |
| Cache | Rails.cache (memory in dev, Solid Cache in prod) | Redis | Same reason: no new service. Cost: the development memory store is per process, so caches are not shared between Puma and workers. Rate limits deliberately avoid the cache for this reason. |
| UI kit | shadcn/ui + Tailwind; ReUI tree; shadcn chart (Recharts) | MUI, Ant Design; React Flow canvas | Copy-in components fit the theme and stay editable. Cost: generated files live in the repo; Recharts adds ~360 kB, lazy-loaded. The org chart moved from a React Flow canvas to the ReUI tree for consistency and accessibility, losing pan/zoom. |

## Security model

| Decision | Chosen | Alternatives | Why / cost |
|---|---|---|---|
| Authentication | Short-lived JWT access token (15 min) + rotating HttpOnly refresh cookie; token-version revocation; 8-hour inactivity | Rails session cookies; long-lived JWTs | Stateless API calls with revocation and idle timeout. Cost: refresh flow and session table to maintain. |
| Authorisation | Pundit policies with scopes for every endpoint | Ad-hoc checks in controllers | One place per resource for visibility rules (HR / manager subtree / self). Cost: a policy and scope class per resource. |
| Integrity | Rules in models **and** database constraints | Model validations only | Survives races and bulk inserts that skip callbacks. Cost: more migrations; constraint errors must be mapped to messages. |
| Bank data in the assistant | Never exposed, even to HR | HR-only exposure | Removes the highest-risk data from an LLM-driven feature. Cost: HR cannot ask about bank details there. |

## Data and workflows

| Decision | Chosen | Alternatives | Why / cost |
|---|---|---|---|
| Leave balances | Append-only ledger (entitlement / used / reversal) | Mutable balance column | Full history and safe recalculation. Cost: balances are aggregates (sum per employee/type/year). |
| Compensation | Append-only history; CTC derived from components | Editable CTC field | No CTC/component mismatch (BR-PAY-08). Cost: corrections are new rows with an effective date. |
| Payroll run states | draft -> generated -> paid; lines store calculated amounts | Compute on export | Reviewable drafts and immutable generated runs. Cost: recalculation needed after leave changes (explicit Recalculate). |
| Export immutability | Freeze employee and bank details onto lines at generation, rebuild XLSX on download | Store the generated file | Same rows on every download, no file storage. Cost: XLSX bytes differ (timestamps); "identical" means identical rows. |
| Employee import | One sheet; two passes (employees, then managers); existing rows rejected; separate update mode | Upsert in one pass; preview step | Clear duplicate semantics and manager references in any order. Cost: a manager error leaves the employee unassigned until an update import (the row carries a warning). Preview deferred. |
| Bulk inserts | activerecord-import with model validations, uniqueness pre-checked | Row-by-row `create!` | 10,007 rows in about 20 s instead of many minutes. Cost: callbacks are skipped, so the service sets derived fields (currency, CTC) itself. |
| Default password | One credential-backed default, hashed once per import | Per-user random passwords | Hashing 10k passwords individually takes tens of minutes; no invitation flow yet. Cost: shared initial password until users change it. |
| One import at a time | PostgreSQL advisory lock + bounded retry | Row-level conflict handling | Simple and safe against overlapping imports. Cost: a second upload waits (retries every 30 s). |

## NL-to-SQL assistant

| Decision | Chosen | Alternatives | Why / cost |
|---|---|---|---|
| Row-level security | Per-request scoped CTEs built from Pundit scopes; model SQL can only name these virtual relations | Inspect model SQL for permission filters; PostgreSQL RLS | Scoping by construction cannot be bypassed by a crafted WHERE clause and reuses existing policies. RLS would duplicate rules in SQL and need a new DB role. Cost: CTE text per query (only referenced CTEs are emitted). |
| SQL validation | pg_query (PostgreSQL's parser) with allowlists | Regex/keyword checks | Parses exactly as PostgreSQL does; rejects writes, multiple statements, catalogs, schema names, unknown functions, reg* casts. Cost: a native gem (+ protobuf). |
| Execution sandbox | Read-only savepoint, 3 s `statement_timeout`, 200-row cap, always rolled back | Separate read-only DB role/connection | Works inside existing transactions (request specs, nested calls). Cost: relies on the application connection; Brakeman warning documented in `config/brakeman.ignore`. |
| Accuracy | Semantic views (top-level managers, leave balances, current compensation, payroll summary) + RTCFC prompt + JSON replies | Per-failure prompt patches; multi-candidate pipelines (CHESS, CHASE-SQL); verified-example retrieval | Semantic layers give the largest proven gains at a few tokens each. Multi-candidate pipelines cost several model calls per question. Verified-example retrieval and model escalation are documented as next steps. |
| Provider | Template-method base class, OpenRouter first, model from config | Hard-wired client | New providers implement five small hooks. Cost: a thin abstraction to maintain. |
| Transparency | SQL never shown to users; stored in the audit table; explanation returned but hidden in the UI | Show SQL | Avoids exposing schema details to non-HR users. Cost: users cannot self-check a query; HR can review audit rows. |
| History | Own history from the audit table; answers re-run on demand | Store result rows; browser storage | No second copy of HR data and always current answers. Cost: re-asking runs the query again (usually cached, no model call). |

## Process

| Decision | Chosen | Cost |
|---|---|---|
| TDD with 50-line review chunks | Small, reviewable steps; every behaviour has a failing test first | Slower per feature; several chunks exceeded 50 lines when markup-heavy and were flagged. |
| One commit per story per repo | Clean history aligned with stories | Large commits; work in progress is uncommitted between sign-offs. |
