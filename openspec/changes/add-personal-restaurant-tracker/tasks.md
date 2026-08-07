## 1. Repository and local stack

- [ ] 1.1 Create the layout from `design.md`: `backend/`, `frontend/`, `infra/`, root `sqlc.yaml`, `Dockerfile`, `docker-compose.yaml`, `Taskfile.yaml`, `.gitignore`, `.env.example`
- [ ] 1.2 Write the root `Taskfile.yaml` with `generate` (depends on `generate:sqlc`, `generate:openapi`, `generate:types`), `build-local`, `up`, `migrate`, and `test`
- [ ] 1.3 Add `docker-compose.yaml` with a `postgres:18` service (named volume, healthcheck) and a one-shot `migrate` service running dbmate that the backend waits on; bind-mount both source trees and install the `task` binary in both dev images
- [ ] 1.4 Add the `develop.watch` blocks from `design.md`: backend watches `app/routers` and `app/schemas` with `sync+exec` → `task generate:openapi`, frontend watches `backend/openapi.json` with `sync+exec` → `task generate:types`, plus `rebuild` on each dependency manifest
- [ ] 1.5 Verify the chain end to end — edit a Pydantic response model, confirm `openapi.json` then `schema.d.ts` regenerate on the host without a manual command, and that Vite HMR picks up the new types
- [ ] 1.6 Write `README.md` setup steps starting with creating a Stytch test project and filling `.env` — the app cannot be signed into without it

## 2. Database schema

- [ ] 2.1 Migration: `users` (`id uuid pk`, `stytch_user_id text unique not null`, `email text not null`, `created_at`)
- [ ] 2.2 Migration: `restaurants` (`id`, `owner_id -> users on delete cascade`, `group_id uuid` reserved and always NULL, `name`, `status`, `tags text[] not null`, optional `image_url`/`website_url`/`instagram_url`/`menu_url`, timestamps)
- [ ] 2.3 Add to `restaurants`: `CHECK (length(trim(name)) between 1 and 200)`, `CHECK (cardinality(tags) >= 1)`, a `status` enum or `CHECK (status in ('tried','want_to_try'))` defaulting to `want_to_try`, a GIN index on `tags`, and an index on `(owner_id, created_at desc)`
- [ ] 2.4 Migration: `restaurant_locations` (`id`, `restaurant_id -> restaurants on delete cascade`, `label`, `lat`, `lon`, `ordinal`) with `unique (restaurant_id, ordinal)`, `CHECK (lat between -90 and 90)`, `CHECK (lon between -180 and 180)`, `CHECK (length(trim(label)) >= 1)`
- [ ] 2.5 Verify `dbmate up` then `dbmate rollback` runs clean against an empty database

## 3. Query layer (sqlc)

- [ ] 3.1 Configure `sqlc.yaml` for `sqlc-gen-python` with the asyncpg driver, schema pointed at `backend/sql/migrations/`, queries at `backend/sql/queries.sql`, output to `backend/generated/`
- [ ] 3.2 Write the user queries: upsert-by-`stytch_user_id` returning the row, and get-by-id
- [ ] 3.3 Write the restaurant write queries: insert, update, delete — each scoped `WHERE owner_id = $1 AND group_id IS NULL` and returning the affected row so a miss is distinguishable from a hit
- [ ] 3.4 Write the location queries: bulk insert for one restaurant, delete-all-for-restaurant, list-by-restaurant ordered by `ordinal`
- [ ] 3.5 Write the read queries: restaurant detail by id, list with optional status / tag / free-text filters (`tags @> ARRAY[$1]`, `ILIKE` over name and location labels), and distinct tags via `unnest` — all owner-scoped
- [ ] 3.6 Run `task generate:sqlc`, commit the generated module, and add a CI check that regenerating produces no diff

## 4. Backend foundation

- [ ] 4.1 Set up the FastAPI project (`pyproject.toml`, `uv`/`pip` lock, `fastapi`, `uvicorn`, `asyncpg`, `stytch`, `pydantic-settings`) and a `Settings` class reading `DATABASE_URL`, `STYTCH_PROJECT_ID`, `STYTCH_SECRET`, `CORS_ORIGINS`
- [ ] 4.2 Add an asyncpg pool on lifespan startup/shutdown and a request-scoped connection dependency, plus a transaction helper for multi-statement writes
- [ ] 4.3 Add `/healthz` returning 200 only when the pool can reach Postgres, for K8s probes
- [ ] 4.4 Configure CORS for the local Vite dev origin only — production is same-origin and needs none
- [ ] 4.5 Mount the built frontend: `StaticFiles` over `frontend/dist` with an SPA catch-all returning `index.html`, registered after the `/api` routes so unknown API paths still return JSON 404; hashed assets get a long `max-age`, `index.html` gets `no-store`

## 5. Authentication

- [ ] 5.1 Implement local Stytch session-JWT verification: fetch and cache JWKS, verify signature/issuer/audience/expiry, refresh JWKS on unknown key id
- [ ] 5.2 Implement the `current_user` dependency — extract the bearer token, verify, upsert the `users` row on first sight, return the local user
- [ ] 5.3 Map failure modes per `specs/user-auth`: missing token → 401, invalid/expired → 401, JWKS unreachable → 503
- [ ] 5.4 Implement `GET /api/me` and a sign-out path that revokes the session at Stytch
- [ ] 5.5 Tests: valid session, missing token, expired token, tampered signature, Stytch unreachable, and first-sign-in provisioning being idempotent under two concurrent requests

## 6. Restaurant API

- [ ] 6.1 Pydantic schemas for restaurant create/update/read and location, enforcing name length, ≥1 location, ≥1 tag, tag length ≤ 50, coordinate ranges, and `http`/`https`-only URLs (rejecting `javascript:`)
- [ ] 6.2 Tag normalisation helper — trim, lowercase, dedupe, preserve first-seen order — applied before every write
- [ ] 6.3 `POST /api/restaurants` — insert restaurant and its locations in one transaction, return 201 with the stored entity
- [ ] 6.4 `GET /api/restaurants/{id}` — owner-scoped detail with locations in `ordinal` order, tags, set optional fields, and status; 404 for anything not owned
- [ ] 6.5 `PATCH /api/restaurants/{id}` — partial update including status; when locations are supplied, delete-and-reinsert inside one transaction; distinguish "clear this optional field" from "leave it alone"
- [ ] 6.6 `DELETE /api/restaurants/{id}` — 204 on success, 404 on miss; confirm cascade removes locations
- [ ] 6.7 `GET /api/restaurants` — list with `status`, `tag`, and `q` filters combining as AND, default ordering newest-first, returning the list-row fields from `specs/personal-list`
- [ ] 6.8 `GET /api/tags` — the signed-in user's distinct tags
- [ ] 6.9 Tests covering every `specs/restaurant-catalog` and `specs/personal-list` scenario, including each 422 case; assert real payloads match each route's declared `response_model` so an undeclared or drifted response fails here
- [ ] 6.10 Ownership isolation test: for every endpoint taking an `{id}`, a second user's request returns 404 and leaves the record untouched
- [ ] 6.11 Give every route an explicit `response_model` and operation id, then add a `task generate:openapi` script that imports the app, calls `app.openapi()`, and writes `openapi.json` without starting a server

## 7. Frontend foundation

- [ ] 7.1 Scaffold Vite + React + TypeScript; add Tailwind, initialise shadcn/ui, add TanStack Query and TanStack Form
- [ ] 7.2 Add the Stytch React provider, a login screen, and a route guard that sends unauthenticated visitors to sign-in
- [ ] 7.3 Wire `openapi-typescript` into `task generate:types`: read the `openapi.json` from 6.11, emit `frontend/src/api/schema.d.ts`, commit it, and extend the CI freshness check to cover it
- [ ] 7.4 Build the API client with `openapi-fetch` rooted at the relative path `/api` (same-origin in production, Vite dev-server proxy locally), with a middleware that attaches the Stytch session JWT as `Authorization: Bearer` and, on 401, clears session state and redirects to sign-in
- [ ] 7.5 Wrap that client with `openapi-react-query` and expose the resulting typed hooks as the only way the app talks to the API — no hand-written fetch calls
- [ ] 7.6 Set up the app shell — header, sign-out, and the routes for list, detail, and add/edit

## 8. Frontend features

- [ ] 8.1 Restaurant list view: cards showing name, status, tags, first location label, and image when set; empty state prompting the first restaurant
- [ ] 8.2 Filter bar — status toggle, tag chips from `/api/tags`, and a search box — with state held in URL search params and used as the query key
- [ ] 8.3 Distinguish "no restaurants yet" from "no matches for these filters" in the empty state
- [ ] 8.4 Install mapcn pointed at the OpenFreeMap style URL (held in config, not hardcoded) and build the location picker: drop/drag a pin, type a label, add and remove locations, reorder preserved on save. If mapcn lacks pin-dropping, fall back to MapLibre GL per `design.md`
- [ ] 8.5 Add/edit form with TanStack Form and Zod schemas mirroring the backend rules; surface server 422 field errors alongside client-side ones
- [ ] 8.6 Restaurant detail view: all locations as pins on a map, tags, and the optional links rendered only when set
- [ ] 8.7 Status toggle on both list and detail, with an optimistic update that rolls back on error
- [ ] 8.8 Delete with a confirmation dialog and cache invalidation on success

## 9. Container and deployment

- [ ] 9.1 Single multi-stage `Dockerfile`: a Node stage running `vite build` with the Stytch public token as a build arg, then a Python runtime stage that copies `dist/` in, installs the backend, adds the dbmate binary for the migration initContainer, and runs as non-root
- [ ] 9.2 Add a `task build-local` target that builds the image and runs it against the compose Postgres, so the production serving path is exercised locally
- [ ] 9.3 Generate the chart with `helm create resto-tracker` in `infra/` — do not hand-write the scaffold; then strip what is unused (the NOTES/test scaffolding as appropriate) and keep the generated `_helpers.tpl`, Deployment, Service, Ingress, ServiceAccount, and HPA
- [ ] 9.4 Add the migration initContainer to the generated Deployment: same image, runs `dbmate up`, requests `cpu: 50m` / `memory: 64Mi`, limits `cpu: 500m` / `memory: 256Mi`
- [ ] 9.5 Add `templates/secret.yaml` — an `InfisicalSecret` modelled on `~/homelab/lubelogger/templates/secret.yaml`, scoped to the `resto-tracker` project, as a `pre-install` hook at weight `-10` (the lowest in the chart, so it is created before every other hook; anything added later takes a strictly greater weight) managing `<fullname>-secrets`; consume it from the Deployment via `envFrom.secretRef` and expose the identity ID, project slug, and env slug as chart values
- [ ] 9.6 Set `image.repository: ghcr.io/kvdomingo/resto-tracker`, `image.tag: latest`, `imagePullPolicy: Always`, and add the Keel `deploymentAnnotations` (`keel.sh/policy: force`, `keel.sh/trigger: poll`, `keel.sh/match-tag: "true"` — no `pollSchedule`, the cluster default applies) wired through `.Values.deploymentAnnotations` as in `~/homelab/lubelogger/templates/deployment.yaml`
- [ ] 9.7 Add liveness/readiness probes on `/healthz`
- [ ] 9.8 Set app resources from `design.md`: requests `cpu: 100m` / `memory: 256Mi`, limits `cpu: 1000m` / `memory: 512Mi`, all four exposed as chart values
- [ ] 9.9 Configure the generated HPA — `minReplicas: 2`, `maxReplicas: 5`, target 70% CPU utilisation — and set the Deployment's `strategy.rollingUpdate.maxUnavailable: 0` so rollouts do not contend with the PDB
- [ ] 9.10 Add the PodDisruptionBudget with `minAvailable: 1`; confirm it is below the HPA floor so a node drain can still evict
- [ ] 9.11 Cap the asyncpg pool at 10 connections per pod so the HPA ceiling stays inside the managed instance's connection limit, and expose it as a chart value alongside `maxReplicas`
- [ ] 9.12 Make sure every value that might need changing under pressure is a real entry in `infra/values.yaml` — image tag, replica bounds, resources, ingress host, Infisical scope — since `--set` does not exist under Argo CD
- [ ] 9.13 Create the Argo CD Application pointing at `infra/` in this repository (following whatever convention the homelab uses for where Application manifests live) and confirm Argo renders the chart and reaches Synced/Healthy
- [ ] 9.14 Observe which field Keel actually patches to force a rollout in this cluster, then add a scoped `ignoreDifferences` for exactly that field so Argo's self-heal stops reverting Keel — do not guess the path from documentation
- [ ] 9.15 Verify the rendered output locally with `helm template` (a developer check, not a deploy path): confirm the HPA, PDB, initContainer, `InfisicalSecret` hook annotations and weight, and Keel annotations all appear as intended

## 10. CI/CD

- [ ] 10.1 Pull-request workflow: run backend tests, frontend typecheck and build, and the codegen freshness check (regenerate sqlc output and `schema.d.ts`, fail on any diff)
- [ ] 10.2 Push-to-`main` workflow: build the image with the Stytch public token as a build arg, and push `ghcr.io/kvdomingo/resto-tracker` as both `latest` and `sha-<commit>`, authenticating with `GITHUB_TOKEN`
- [ ] 10.3 Gate the push on the same checks as 10.1 so nothing reaches `latest` with stale generated code
- [ ] 10.4 Confirm no cluster credentials exist anywhere in the workflows, and that CI never commits back to `infra/` — code reaches the cluster via Keel pulling the image, config via Argo pulling git, and the two paths stay separate

## 11. Verification

- [ ] 11.1 Full local run from a clean checkout: `docker compose up` → migrations apply → sign in with a Stytch test user → add a restaurant with two locations and three tags → filter by tag → mark tried → delete
- [ ] 11.2 Repeat the same walkthrough against `task build-local`, confirming the served bundle loads, a deep link like `/restaurants/{id}` refreshes without a 404, and an unknown `/api/*` path returns JSON rather than the HTML shell
- [ ] 11.3 Confirm every scenario in `specs/user-auth`, `specs/restaurant-catalog`, and `specs/personal-list` has a corresponding passing test
- [ ] 11.4 Confirm `task generate` is idempotent on a clean tree — both the sqlc output and `schema.d.ts` regenerate byte-identical — and that a deliberate field rename in a Pydantic model breaks `tsc` rather than passing silently
- [ ] 11.5 Record actual CPU and memory usage of the app container during the 11.2 walkthrough and reconcile against the requests in 9.8; adjust the chart values if they are off by more than roughly 2×
- [ ] 11.6 Confirm the initContainer path: two replicas starting simultaneously against an unmigrated database both come up, with dbmate's advisory lock serialising them and only one set of migrations applied
- [ ] 11.7 Confirm Keel has adopted the Deployment — annotations present, polling, and a pushed image actually triggers a rollout
- [ ] 11.8 Confirm Argo and Keel coexist: after a Keel-triggered rollout, the Application returns to Synced/Healthy and the new pods are still running some minutes later, i.e. self-heal did not revert them
- [ ] 11.9 Confirm the incident path works: commit `image.tag: sha-<known-good>` to `infra/values.yaml`, watch Argo pin it, then revert and confirm Keel resumes
- [ ] 11.10 Run `openspec validate --strict` on this change
