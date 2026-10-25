# Prompt Log

## 2026-10-23

### Scaffold the Rails app

> Create a new Rails API-only app with PostgreSQL with the latest version.

Notes: Generated a Rails 8.1.4 API-only app with PostgreSQL 18.6, configured
`config/database.yml` for local TCP connections, and created the development and
test databases.

### Prompt log folder

> Create a separate folder inside this repo for logging my prompts.

Notes: Added the `prompts/` folder with this log and a short README describing the
format.

### HR discovery: Excel-based HR for 10,000 employees

> First I need to understand how HR managers work. Let's consider an HR team that
> manages around 10,000 employees within different countries, all maintained in
> Excel sheets. What are the problems they face every day? What will be their
> day-to-day work and how long will it take? Just explain these things to me.
> List these things for me.

Notes: Domain/discovery discussion only, no code changes. Covered the problems of
spreadsheet-based HR at scale, the recurring work of an HR team, and typical manual
effort and cycle times.

## 2026-10-24

### Product requirements for the eight in-scope HR workstreams

> In the above, except for statutory or compliance filing, benefits administration,
> performance and training admin, and audit and reconciliations: prepare a
> requirements document for the rest of the tasks for a software product.

Notes: Created `docs/requirements.md` covering employee master data, onboarding,
offboarding, payroll inputs, leave and attendance, reporting, employee queries, and
recruitment coordination, plus cross-cutting and non-functional requirements.

### Simplify requirements for a demo scope

> 1. This is a demo application, so we don't need this many roles. Maybe the hierarchy
> of employees, new candidates and then the HR team who manages everything on a single
> go. That's enough. 2. Here we have two different roles: employee and manager. In a
> real company it will be a hierarchy. Maybe a manager is reporting to a head manager,
> a senior manager, or someone like him. It should be based on hierarchy. The approval
> and requesting leave should be based on hierarchy not based on role. 3. Most
> country-based policies are not required right now. Only different countries, and they
> are moving from one country to another. That's fine. Country-based policies,
> country-based taxations, all those things are not required right now since this is a
> demo application. 4. Right now, there is no identity verification or something like
> that, only the source of proof: the Excel and the form that the new candidate is going
> to fill. No verifications of those fields which are entered by the candidate or from
> the Excel. We don't need that right now. 5. No payroll providers, too. We are just
> going to return that this is the monthly payroll that should be paid out, maybe in a
> separate Excel, pointing out each employee, his account, his account number, and bank
> details. 6. In integration only, email, time and attendance devices are enough.

Notes: Rewrote `docs/requirements.md` as v0.2 for a demo: three authenticated roles
(employee, manager, HR) plus candidates, hierarchy-based approvals, country as a plain
field with transfers, no verification, no country policies/tax, payroll as an Excel
payout export, and only email/attendance integrations.

### Apply demo decisions and resolve open questions

> open questions: 1. will provide will implementing the import feature. 2. India, USA,
> Canada 3. earned, sick, casual. 4. reset 5. yearly CTC is preferred while the breakup
> will be provided by the HR team, the excel will already have them. 6. yes 7. account
> number, ifsc, bank name 8. will give at the time of implementing the feature,
> basically (timestamps of first in and last out, employee id) 9. since it is demo, we
> gonna use only localhost now. 10. no 11. employee queries feature is not required for
> now. 12. a separate login for candidate is required, once selected, a new employee
> record will be created which will have reference of that candidate record. 13. we need
> a seed file of 10000 records of employees, 100 candidates, attendance of last 2 months.
> We may use Faker gem for it. 14. is based on country of the employee.
> wrong assumptions: candidates will have records.

Notes: Updated `docs/requirements.md` to v0.3: four authenticated roles including
candidates, candidate-to-employee reference, countries India/USA/Canada with
country-derived currency, earned/sick/casual/unpaid leave, annual CTC with imported
components, unpaid leave pay deduction, IFSC bank fields, localhost SMTP, employee
queries removed, and a 10,000-employee/100-candidate/2-month attendance seed.

### Generate sequential product stories and test cases

> With the above requirements file, generate product documents with multiple stories,
> each with a testable feature, along with test cases. The story should grow in a linear
> way, that the product should be tested in a sequential manner.

Notes: Added `docs/product-stories.md` (22 sequentially dependent stories, 158 test
cases) and `docs/test-plan.md` (execution order, environments, regression pack,
traceability), plus `docs/README.md` as the documentation index.

## 2026-10-25

### Add repository agent rules and prompt logging

> Generate an agents.md file for this repository, which should contain the basic logging
> of every prompt and several sets of development rules as follows:
> 1. Every implementation should follow the TDD approach using Rspec.
> 2. Every implementation should be split up into 50-line code chunks that I will review
> after every 50 lines. Once I review it, it should go on to the next 50-line chunk.
> 3. self-descriptive code with minimal comments; enterprise best practices (DRY, N+1
> awareness, heavy concurrency and race conditions); no unilateral decisions — ask
> questions first.

Notes: Added `AGENTS.md` with mandatory prompt logging, TDD/RSpec workflow, the 50-line
review gate, engineering and testing standards, and open decisions to confirm before
implementation.

### Confirm stack and working rules

> 1. We gonna use a React application for FE.
> 2. remove
> 3. use jwt
> 4. pundit
> 5. use mailhog
> 6. exclude specs/factories, just one line descriptions of tests before writing them
> 7. per story
> 8. will provide at S06 and S16

Notes: Recorded the stack decisions in `AGENTS.md`: React frontend, RSpec with Minitest
`test/` removed, JWT authentication, Pundit authorisation, Mailhog, production-only
50-line counts with one-line test descriptions, per-story commits, and fixtures at
S06/S16. Updated the requirements and test plan to name Mailhog.

### Confirm JWT, frontend, and API contract defaults

> JWT approach: jwt gem + password. Frontend setup: Vite + React + TS. API contract: v1 + offset paging.

Notes: Confirmed the S01 implementation defaults: `jwt` gem with `has_secure_password`,
Bearer access/refresh tokens and token-version revocation; React app in `frontend/` with
Vite, TypeScript, and Vitest/RTL; `/api/v1` with the agreed error envelope, offset
pagination, and CORS for `http://localhost:5173`. Updated `AGENTS.md` accordingly.

Setup chunk S00-1: added `rspec-rails`, `factory_bot_rails`, `faker`, `jwt`, `pundit`,
`bcrypt`, and `rack-cors`; removed the Minitest `test/` directory; configured FactoryBot,
the RSpec generators, Mailhog SMTP (`localhost:1025`), and the CORS initializer. Added two
smoke examples; `bundle exec rspec` passes (2 examples) and `bin/rubocop` is clean.

### Create separate React repository beside the backend

> create a FE repo parallel to the incubyte folder named incubyte-BE for the react app, we will build the FE along with the every story

Notes: Awaiting confirmation of the repository name (`incubyte-BE` versus `incubyte-FE`)
before scaffolding; no files created yet. Clarified in the next entry.

### Confirm frontend repo name and per-story commits

> Repo name: incubyte-FE. Initial git commit: yes. Story commits: one per story in both repos.

Notes: Created the sibling repo `../incubyte-FE` with Vite 8 + React 19 + TypeScript,
Vitest 5 + React Testing Library, jsdom, and Oxlint. Added a `/api` proxy to Rails on
port 3000, replaced the Vite demo with a minimal app shell, and added one smoke test.
`npm test` passes (1 test); `npm run build`, `npm run typecheck`, and `npm run lint` pass.
Initialized git and committed the scaffold as `18bd67d` (`chore: scaffold React frontend`).
Updated `AGENTS.md` to treat the frontend as a sibling repo, count React production lines,
run both test suites at each checkpoint, and commit once per story in both repos. Added a
frontend `AGENTS.md` that points to the backend rules and lists the frontend commands
(committed as `2f64beb`).

### Commit the pending setup changes

> commit now

Notes: Committed all pending backend setup and documentation changes as a single pre-S01
baseline commit, including RSpec/FactoryBot/Faker, JWT/Pundit/bcrypt/rack-cors, Mailhog,
CORS, the removed Minitest directory, and the updated agent instructions and docs. The
frontend repository was already clean.






