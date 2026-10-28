# Architecture

State as of 2026-10-28: stories S01–S06, S08–S11, S11a, S11b and S11c are built (S07 cut). Diagrams
use Mermaid and render on GitHub and in most Markdown viewers.

## 1. System context

```mermaid
flowchart LR
  user["HR / manager / employee<br/>(browser)"]
  spa["React SPA<br/>../incubyte-FE<br/>Vite · TypeScript · shadcn/ui"]
  api["Rails 8.1 API<br/>/api/v1 · Puma"]
  jobs["Solid Queue workers<br/>bin/jobs"]
  pg[("PostgreSQL 18<br/>primary + queue DBs")]
  cache[("Rails.cache<br/>memory (dev) · Solid Cache (prod)")]
  llm["OpenRouter<br/>LLM provider"]
  mail["Mailhog<br/>SMTP (dev)"]

  user --> spa
  spa -- "JSON over HTTPS<br/>Bearer access token<br/>+ HttpOnly refresh cookie" --> api
  api --> pg
  api --> cache
  api -- "enqueue" --> pg
  jobs -- "claim / run" --> pg
  api -- "schema + question only<br/>(never data rows)" --> llm
  api --> mail
```

- The backend is API-only; the SPA is the only client. CORS is an explicit allowlist.
- Background work (leave import, employee import, payroll calculation) runs in Solid Queue, which
  stores its jobs in a separate PostgreSQL database.
- The LLM receives the scoped schema text and the question; result rows never leave the server.

## 2. Backend layers

```mermaid
flowchart TB
  subgraph HTTP["HTTP boundary"]
    routes["config/routes.rb<br/>/api/v1/*"]
    controllers["Thin controllers<br/>app/controllers/api/v1"]
  end
  subgraph Auth["Authentication & authorisation"]
    jwt["AccessToken (JWT HS256)<br/>exp · iss · aud · token_version"]
    pundit["Pundit policies + Scopes<br/>app/policies"]
  end
  subgraph Domain["Domain"]
    services["Service objects<br/>app/services (payroll, employees, leaves, assistant)"]
    queries["Query objects<br/>app/queries (reports, org chart)"]
    models["ActiveRecord models<br/>validations + DB constraints"]
  end
  jobs2["Jobs<br/>app/jobs"]
  db[("PostgreSQL")]

  routes --> controllers --> jwt
  controllers --> pundit
  controllers --> services
  controllers --> queries
  controllers --> jobs2
  jobs2 --> services
  services --> models --> db
  queries --> db
  pundit --> models
```

Rules applied throughout:

- Controllers authorise (`authorize`, `policy_scope`), call one service or query object, and render
  the JSON envelope (`{ data, meta }` or `{ error: { code, message, details } }`).
- Visibility lives in policy scopes: HR sees everything; a manager sees their reporting subtree
  (`Employee#subordinate_ids`, recursive CTE); an employee sees their own records.
- Integrity lives in the database as well as the models: unique indexes, check constraints
  (statuses, positive amounts, `paid_on` when paid), foreign keys, an append-only leave ledger.

## 3. Authentication and session flow

```mermaid
sequenceDiagram
  participant B as Browser (SPA)
  participant A as Rails API
  participant D as PostgreSQL
  B->>A: POST /auth/sign_in (email, password)
  A->>D: User + bcrypt check, create UserSession
  A-->>B: access token (15 min, JSON) + refresh cookie (HttpOnly, rotating)
  B->>A: API call with Authorization: Bearer
  A->>A: verify signature, exp, iss, aud, token_version
  Note over B,A: access token expires
  B->>A: POST /auth/refresh (cookie)
  A->>D: rotate session, reject if idle over 8 h or revoked
  A-->>B: new access token + new refresh cookie
  B->>A: DELETE /auth/sign_out
  A->>D: revoke session (token_version / session row)
```

## 4. Main workflows

### 4.1 Excel imports (leave and employees)

```mermaid
sequenceDiagram
  participant HR as HR (SPA)
  participant API as API
  participant Q as Solid Queue
  participant W as Worker
  participant DB as PostgreSQL
  HR->>API: POST /employee_imports (xlsx, mode)
  API->>DB: EmployeeImport(status: queued) + Active Storage blob
  API->>Q: enqueue ImportEmployeeSheetJob
  API-->>HR: 202 + import id
  W->>DB: pg_try_advisory_lock (one employee import at a time)
  W->>DB: claim queued -> processing (atomic UPDATE)
  W->>W: SheetParser (roo) -> rows + row errors
  W->>DB: pass 1: bulk insert employees, users, compensation, entitlements (activerecord-import, 1,000-row batches)
  W->>DB: pass 2: map managers (cycle checks, one UPDATE per manager)
  W->>DB: status completed + row_errors
  loop every 2 s
    HR->>API: GET /employee_imports/:id?errors_page=n
  end
```

The leave import follows the same shape (upload -> job -> per-row validation -> ledger entries ->
summary) and keeps balances append-only.

### 4.2 Payroll

```mermaid
stateDiagram-v2
  [*] --> draft: POST /payroll_runs (month)
  draft --> draft: CalculatePayrollRunJob (queued -> processing -> completed / failed)
  draft --> draft: recalculate (completed or failed only)
  draft --> generated: generate (completed, no blocking issues, freezes employee and bank details on lines)
  generated --> paid: mark_paid (paid_on <= today)
  generated --> generated: export XLSX (rebuilt from frozen lines)
  paid --> paid: export XLSX
```

### 4.3 NL-to-SQL assistant

```mermaid
flowchart TB
  q["POST /assistant/queries<br/>question"] --> rate{"Rate limit<br/>(audit table)"}
  rate -- exceeded --> r429["429 rate_limited"]
  rate -- ok --> rc{"Result cache<br/>user + question, 5 min"}
  rc -- hit --> ans["Answer (cached)"]
  rc -- miss --> sc{"SQL cache<br/>tier + schema digest + question, 1 day"}
  sc -- hit --> val
  sc -- miss --> budget{"Daily token budget"}
  budget -- exceeded --> r429
  budget -- ok --> llm["LlmProvider.complete<br/>RTCFC prompt + scoped schema<br/>JSON reply: status, sql, failure_reason"]
  llm -- "cannot_answer /<br/>needs_clarification" --> r422["422 with model reason"]
  llm -- success --> val["SqlValidator (pg_query)<br/>single SELECT, allowed relations,<br/>allowlisted functions, no schema names"]
  val -- unsafe --> repair{"One repair attempt"}
  val -- ok --> exec["Executor<br/>WITH scoped CTEs + views<br/>read-only savepoint, 3 s timeout, 201-row limit"]
  exec -- error --> repair
  repair -- retry --> llm
  repair -- "second failure" --> r422b["422 unsafe_query / cannot_answer"]
  exec -- rows --> ans
  ans --> audit[("assistant_queries<br/>append-only audit")]
  r422 --> audit
  r422b --> audit
```

Scoping by construction: the model only ever names virtual relations (`employees`,
`leave_records`, `payroll_summary`, ...). Each one is a CTE built from the asker's Pundit scope and an
allowed column list, so whatever SQL is generated cannot read rows or columns outside the asker's
visibility.

```mermaid
flowchart LR
  user["Signed-in user"] --> scope["AssistantPolicy::Scope<br/>HR: all · others: self + subtree"]
  scope --> ctes["Base CTEs<br/>employees, departments, leave_*, (HR) compensations, payroll_*"]
  ctes --> views["Semantic views<br/>employee_top_managers, leave_balances,<br/>(HR) current_compensation, payroll_summary"]
  views --> sql["Model SQL<br/>(referenced relations only)"]
```

Provider template pattern:

```mermaid
classDiagram
  class LlmProvider {
    +build(config)$
    +complete(system, message) Completion
    -post(uri, headers, payload)
    #endpoint()*
    #headers()*
    #build_payload(system, message)*
    #extract_text(response)*
    #extract_usage(response)*
  }
  class OpenRouterProvider
  LlmProvider <|-- OpenRouterProvider
```

## 5. Data model (core)

```mermaid
erDiagram
  USERS ||--o| EMPLOYEES : "logs in as"
  ROLES ||--o{ USERS : has
  USERS ||--o{ USER_SESSIONS : has
  DEPARTMENTS ||--o{ EMPLOYEES : contains
  EMPLOYEES ||--o{ EMPLOYEES : "manages (manager_id)"
  EMPLOYEES ||--o{ COMPENSATIONS : "append-only history"
  COMPENSATIONS ||--o{ COMPENSATION_COMPONENTS : "Basic / HRA / Special Allowance"
  EMPLOYEES ||--o{ LEAVE_RECORDS : takes
  LEAVE_TYPES ||--o{ LEAVE_RECORDS : classifies
  EMPLOYEES ||--o{ LEAVE_LEDGER_ENTRIES : "entitlement / used / reversal"
  LEAVE_IMPORTS ||--o{ LEAVE_RECORDS : created
  PAYROLL_RUNS ||--o{ PAYROLL_LINES : contains
  EMPLOYEES ||--o{ PAYROLL_LINES : "paid in"
  USERS ||--o{ EMPLOYEE_IMPORTS : uploads
  USERS ||--o{ ASSISTANT_QUERIES : asks
```

## 6. Frontend structure

```mermaid
flowchart TB
  app["App.tsx<br/>routes + guards (RequireAuth, RequireHr, RequireReportAccess, RequireManager)"]
  shell["AppShell<br/>shadcn Sidebar, role-filtered sections"]
  pages["pages/*<br/>Dashboard, Employees, Org chart, Leave, Payroll, Reports, Imports, Assistant, Settings"]
  comps["components/*<br/>PageHeader, StatusBadge, Pager, DashboardTiles, DashboardTrends (lazy), reports/*"]
  ui["components/ui<br/>shadcn: button, card, table, badge, sidebar, chart, reui tree"]
  api["api/*<br/>typed fetch clients (request + bearer)"]
  auth["auth/AuthContext<br/>session, refresh, sign-out"]
  app --> shell --> pages
  pages --> comps --> ui
  pages --> api
  app --> auth
  api --> auth
```

The SPA hides links by role for convenience only; the API enforces every rule.
