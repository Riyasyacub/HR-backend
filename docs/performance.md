# Performance considerations

Measured on a development machine (WSL2, PostgreSQL 18.6) with the demo data set: 10,009 employees,
about 7,500 leave records, two payroll runs. Targets come from `docs/test-plan.md` §9.

## 1. Measured results

| Operation | Target | Measured |
|---|---|---|
| Generate the 10,000-employee demo workbook | — | 3.2 s, 1.1 MB |
| Employee Excel import, 10,007 rows (job run time) | < 10 min | **19.7 s**, 0 row errors |
| Demo leave seed (two months, 30% sample) | — | 3.4 s |
| Full seed (workbook + import + leave) | < 15 min | under 30 s |
| Assistant rollup query (payroll by top-level manager, 10,007 lines) | 3 s timeout | 37 ms |
| Assistant end-to-end answer (model call included) | — | about 1.5–4.5 s, dominated by the model |
| Frontend main bundle | Vite 500 kB warning | 472 kB (146 kB gzip); charts lazy-loaded (359 kB) |

## 2. Database access patterns

**No N+1 on lists.** Lists preload associations and specs count queries, for example:

- employee directory, payroll lines, joiners report: one query for rows plus one per preloaded
  association, whatever the page size;
- org chart nodes: report counts come from a correlated subquery inside the node query;
- leave report: 5 queries per page (types, page ledger totals, page unpaid days, filtered totals);
- trends report: four aggregate queries for any window of 1–24 months;
- assistant focus path: one recursive CTE for the manager chain, whatever the depth.

**Aggregates in SQL, not Ruby.** Headcount, payroll totals, currency totals, leave balances and
trends use `GROUP BY` / `FILTER` in PostgreSQL. Ruby only formats results.

**Pagination everywhere.** Offset pagination with `per_page` capped (100 for lists, 200 for
assistant rows, 200 for import error pages). Import row errors are paged server-side so polling
stays small (50 errors per response instead of up to 10,007).

**Indexes that matter.**

| Index | Used by |
|---|---|
| `employees(employee_id)`, `employees(work_email)` unique | imports, lookups |
| `employees(manager_id)` | hierarchy, subtree CTEs, org chart |
| `leave_records(employee_id, leave_date)` unique | leave import idempotency, reports |
| `leave_ledger_entries(employee_id, leave_type_id, year)` (+ partial unique for entitlement) | balances, entitlement upserts |
| `payroll_lines(payroll_run_id, employee_id)` unique | run lines, exports |
| `assistant_queries(user_id, created_at)` | rate limit, daily budget, history |

**Recursive hierarchy.** Subtrees and manager chains use recursive CTEs (`Employee#subordinate_ids`,
`#manager_chain_ids`, the `employee_top_managers` view). At the demo depth (6 levels) these run in
milliseconds; a depth guard of 100 protects against bad data.

## 3. Bulk work

- **Imports** run in Solid Queue jobs, never in the request. Uploads return `202` and the client polls.
- **Employee import** inserts in 1,000-row batches inside transactions with activerecord-import:
  one `INSERT` per batch for employees, users, compensations, components and ledger entries, plus one
  `UPDATE` per distinct manager in pass 2. Uniqueness is pre-checked with two lookups per file rather
  than one query per row.
- **Password hashing** for imported users happens once per import (bcrypt at normal cost); hashing
  each user would take tens of minutes at 10k rows.
- **Leave seed and exports** process employees in batches of 1,000; exports use `pluck` instead of
  building model objects. The XLSX itself is built in memory by caxlsx, which is fine at 10k rows
  (about 1 MB); very large exports would need a streaming writer.
- **Only one employee import runs at a time** (advisory lock), so imports never compete for the same
  unique keys; a second import retries every 30 seconds.

## 4. Assistant cost and latency

Cost is dominated by model tokens; latency by the model round trip.

| Control | Effect |
|---|---|
| Result cache (5 min, per user + normalised question) | repeat questions return instantly with no model call or query |
| SQL cache (1 day, per access tier + schema digest + question) | other users in the same tier reuse SQL; the query still runs in their scope |
| Static prompt first, per-user schema after | providers with prompt caching reuse the ~256-word instruction head |
| Only referenced CTEs emitted | smaller statements; PostgreSQL skips unreferenced CTEs anyway |
| `temperature 0`, `max_tokens 400`, JSON mode | short, deterministic replies |
| One repair attempt only | at most two model calls per question |
| Rate limit 10/min and 50,000 tokens/day per user (from the audit table) | bounds spend and abuse; works across processes |
| 3 s statement timeout, 200-row cap | protects the database from runaway queries |

Typical question: ~850 prompt + ~110 completion tokens with the default low-cost model.

## 5. Frontend

- Charts (Recharts) load only with the dashboard trends section (`React.lazy`), keeping the main
  bundle under the warning threshold.
- Lists fetch one page at a time; filters apply on submit, not on every keystroke.
- Import pages poll every 2 seconds only while a job is queued or processing.
- The org chart loads one level at a time and remembers expanded nodes; focusing an employee costs
  one path request plus one request per manager on the chain (about 6 at the demo depth).

## 6. Known limits and next steps

- **Offset pagination** slows on very deep pages; keyset pagination would be needed beyond ~100k rows.
- **Headcount trend** is derived from start dates; switch to stored monthly snapshots once leavers exist.
- **Development cache** is per process (memory store); use Solid Cache or Redis when running several
  workers that should share assistant caches.
- **XLSX generation** is in memory; move to a streaming writer if exports grow well beyond 10k rows.
- **Assistant accuracy/cost**: a verified-examples library and cheap-to-strong model escalation are the
  documented next steps.
