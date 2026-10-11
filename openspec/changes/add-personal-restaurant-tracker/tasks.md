## 1. Repository and local stack

- [x] 1.1 Create the layout from `design.md`: `api/`, `ui/`,
      `infra/helm/resto-tracker/`, root `Taskfile.yml`, `docker-compose.yml`,
      `mise.toml`, `.pre-commit-config.yaml` (prek), `.gitignore`,
      `.env.example`, `api/sqlc.yaml`
- [x] 1.2 Taskfile workflow targets: `setup`, `up` (Infisical-wrapped
      `docker compose up --watch`), `stop`/`logs`/`restart`/`down`/`clean`/
      `exec`, `pgcli`, `makemigrations`, `migrate`, `unmigrate`,
      `load-fixtures`
- [ ] 1.3 Add the missing Taskfile targets: `generate` (depends on
      `generate:sqlc`, `generate:openapi`, `generate:types`), `build-local`,
      and `test`
- [x] 1.4 `docker-compose.yml`: `db` on `ghcr.io/kvdomingo/postgresql-pig:18`
      (named volume, healthcheck), a one-shot dbmate `migrations` service in the
      `admin` profile, and `api`/`ui` dev services with bind mounts, Infisical
      injection, and restart-on-dependency-change watches
- [ ] 1.5 Add codegen-on-save `develop.watch` hooks: `api` watches
      `app/routers` and `app/models` with `sync+exec` → `task
      generate:openapi`, and `ui` watches `api/openapi.json` with `sync+exec` →
      `task generate:types`. Verify that editing a response model regenerates
      `generated.d.ts` on the host and Vite HMR picks it up
- [ ] 1.6 Write `README.md` setup steps: Infisical access, a Stytch test project
      with an OAuth provider and redirect URL, then `task migrate`,
      `task load-fixtures`, `task up`

## 2. Database schema

- [x] 2.1 Initial migration: `users` (ULID `id`, unique `idp_user_id`, unique
      citext `email`, `name`), `restaurants` (`created_by_id` `ON DELETE SET
      NULL`, `price_tier` 1–5, `instagram_handle`, `website`, `menu_url`,
      `is_reservation_required`), `tags` (unique citext `name`),
      `restaurant_tags`, `restaurant_branches` (`GEOGRAPHY(POINT)` + GiST),
      `restaurant_visits`, `reviews`, `groups`, `group_memberships`
- [x] 2.2 Migration: `restaurant_branch_list` JSONB domain for the typed branch
      aggregate
- [x] 2.3 Fixtures: system user and sample restaurants with branches and tags,
      loaded by `task load-fixtures`
- [ ] 2.4 Migration: give `restaurant_visits` a primary key
      `(user_id, restaurant_id)`, `created_at TIMESTAMPTZ NOT NULL DEFAULT
      now()`, and `ON DELETE CASCADE` on both FKs. Without the cascade,
      deleting a restaurant or user that has visits fails today
- [ ] 2.5 Migration: `CHECK (length(trim(name)) BETWEEN 1 AND 200)` on
      `restaurants`, `CHECK (length(trim(label)) >= 1)` on
      `restaurant_branches`, `CHECK (length(trim(content)) >= 1)` on `reviews`,
      and indexes on `restaurants (created_by_id)`, `reviews (restaurant_id)`,
      and `restaurant_visits (user_id, created_at DESC)`
- [ ] 2.6 Verify `dbmate up` then `dbmate rollback` runs clean against an empty
      database, and `schema.sql` is committed with each migration

## 3. Query layer (sqlc)

- [x] 3.1 Configure `api/sqlc.yaml` for the `kvdomingo/sqlc-gen-python` wasm
      plugin: schema from the dbmate `schema.sql`, queries from
      `app/repositories/sql/queries/`, output to `app/repositories/generated/`,
      pydantic models, async querier, and overrides for citext and
      `restaurant_branch_list`
- [x] 3.2 User queries: get by id, get by `idp_user_id`, create, update, delete
- [ ] 3.3 Replace get-then-create in the callback with an upsert on
      `idp_user_id` (`ON CONFLICT ... DO UPDATE SET email, name RETURNING *`)
- [x] 3.4 Restaurant queries: get, list, list-in-bbox with aggregated branches,
      create, partial update, delete
- [ ] 3.5 Scope restaurant update/delete to `created_by_id = @user_id`, and let
      the update clear optional fields (the `COALESCE` pattern cannot set a
      column to NULL)
- [ ] 3.6 Branch queries: bulk insert for a restaurant, delete all for a
      restaurant. Extend the detail query with branches, tags, and rating summary
- [ ] 3.7 Tag queries: get-or-create by name, replace a restaurant's tag set,
      list all tags. Add tags and rating summary to the list-in-bbox rows
- [ ] 3.8 Add `q` (ILIKE over name and branch labels) and `tag` filters to
      list-in-bbox, order newest first (`ORDER BY r.id DESC`), and return a
      total count
- [ ] 3.9 Visit queries: upsert a status, delete, get the viewer's status for
      one restaurant, and list a user's visits with status/tag/`q` filters,
      newest first
- [ ] 3.10 Review queries: create, list for a restaurant, update and delete
      scoped to `author_id = @user_id`
- [ ] 3.11 Add a CI check that `sqlc generate` after migrations produces no diff

## 4. Backend foundation

- [x] 4.1 FastAPI project with uv (`pyproject.toml`, ruff, ty, sqlfluff) and
      `Settings` reading `PYTHON_ENV`, `SECRET_KEY`, `DATABASE_URL` (coerced to
      `postgresql+asyncpg`), the Stytch project ID/public token/secret,
      `STYTCH_CALLBACK_URL`, and `APP_URL`
- [x] 4.2 SQLAlchemy async engine with the geoalchemy2 plugin and a
      pass-through `geography` codec, plus a request-scoped `Queriers`
      dependency
- [x] 4.3 `/api/health`, Scalar docs at `/api/docs`, and routers auto-registered
      under `/api`
- [x] 4.4 Serve the built frontend in production with
      `app.frontend("/", directory="static", fallback="index.html")` after the
      `/api` routers
- [ ] 4.5 Make `/api/health` check database reachability so K8s probes
      reflect it
- [ ] 4.6 Make the engine's `pool_size` and `max_overflow` settings, defaulting
      to 10 connections per pod in total
- [ ] 4.7 Verify that an unknown `/api/*` path returns JSON 404 rather than
      `index.html`, hashed assets get a long `max-age`, and `index.html` gets
      `no-store`

## 5. Authentication

- [x] 5.1 Stytch client singleton and `GET /api/auth/login` returning the OAuth
      start URL
- [x] 5.2 `GET /api/auth/callback`: authenticate the OAuth token, provision the
      local user, store `session_token`/`session_jwt` in the signed cookie
      session, 303 to `APP_URL`
- [x] 5.3 `StytchAuthBackend` verifying the session per request and attaching
      `AppUser` with the `authenticated` scope plus Stytch roles, and `get_user`
      raising 401/403
- [x] 5.4 `GET /api/auth/logout` (revoke at Stytch, clear the cookie, 303) and
      `GET /api/auth/me`
- [ ] 5.5 On a failed or cancelled OAuth callback, redirect to `APP_URL` with an
      error indicator the UI can show, instead of a bare 400/500, and cover
      the case where the response is neither success nor a classified error
- [ ] 5.6 Tell a Stytch rejection (clear cookie, continue anonymous) apart from
      a Stytch outage (keep the cookie, 503 on endpoints that need a user)
- [ ] 5.7 Tests: valid session, no session, rejected session, Stytch
      unreachable, concurrent first sign-in creating one user, sign-out
      invalidating the session

## 6. Restaurant API

- [x] 6.1 `GET /api/restaurants`: public, bbox (`n`/`e`/`s`/`w` validated),
      paginated (`page`, `page_size` ≤ 100), each row with its branches and
      coordinates
- [x] 6.2 `GET /api/restaurants/{id}` returning 404 on a miss
- [x] 6.3 `POST`/`PATCH`/`DELETE /api/restaurants` route stubs over the
      generated queries, with `POST` requiring sign-in and setting
      `created_by_id` from the session
- [ ] 6.4 Hand-written Pydantic request models replacing the sqlc params as
      request bodies: name 1–200 after trim, price tier 1–5, ≥ 1 branch with a
      non-blank label and valid coordinates, ≥ 1 tag of ≤ 50 characters,
      `http`/`https`-only URLs, an optional initial `status`. No `id` or
      `created_by_id` in the body
- [ ] 6.5 Tag normalisation helper: trim and dedupe case-insensitively,
      preserving first-seen order, applied before every write
- [ ] 6.6 `POST /api/restaurants`: insert the restaurant, branches, tags, and
      optional status in one transaction, and return 201 with the stored entity
- [ ] 6.7 `PATCH /api/restaurants/{id}`: require sign-in and creator only (403
      otherwise, 404 on a miss). When branches or tags are supplied, replace
      them in the same transaction. Distinguish "clear this optional field"
      from "leave it alone"
- [ ] 6.8 `DELETE /api/restaurants/{id}`: require sign-in and creator only, 204
      on success, 404 on a miss. Confirm that branches, tags, reviews, and
      visits go with it
- [ ] 6.9 `GET /api/restaurants/{id}`: include branches, tags, rating summary,
      and the viewer's status when signed in
- [ ] 6.10 `GET /api/restaurants`: add `q` and `tag` filters, newest-first
      ordering, `total_count`, and tags plus rating summary on each row.
      `GET /api/tags` lists all tags
- [ ] 6.11 Personal list: `PUT`/`DELETE /api/restaurants/{id}/status` and
      `GET /api/me/restaurants` with `status`, `tag`, and `q` filters
- [ ] 6.12 Reviews: `GET`/`POST /api/restaurants/{id}/reviews` and
      `PATCH`/`DELETE /api/reviews/{id}` (author only). Omit the author on
      anonymous reviews unless the reader is the author
- [ ] 6.13 Tests covering every `specs/restaurant-catalog` and
      `specs/personal-list` scenario, including each 422 case, and asserting
      that real payloads match each route's declared `response_model`
- [ ] 6.14 Access-rule tests from `specs/user-auth`: anonymous writes return
      401, non-creator restaurant edits/deletes and non-author review
      edits/deletes return 403 and leave data untouched, and one user's list
      never shows another's statuses
- [ ] 6.15 Give every route an explicit `response_model` and operation id, then
      add `task generate:openapi`, which imports the app and writes
      `openapi.json` without starting a server

## 7. Frontend foundation

- [x] 7.1 Scaffold TanStack Start with file-based Router, Tailwind v4,
      shadcn/ui, TanStack Query/Form, biome, bun, and the React Compiler
- [x] 7.2 `$api` client via `openapi-fetch` + `openapi-react-query` with
      cookie credentials, typed from `src/types/generated.d.ts`
      (`generate-api-types`)
- [x] 7.3 nitro dev proxy forwarding `/api/**` to the `api` container, keeping
      dev same-origin
- [x] 7.4 Navbar: home link, debounced search box held in URL state, sign-in
      link from `/api/auth/login`, avatar menu with sign-out, "add" menu when
      signed in
- [ ] 7.5 Configure TanStack Start SPA mode so `vite build` emits static assets
      plus an `index.html` shell for FastAPI to serve, and drop the
      SSR-specific wiring (`react-router-ssr-query`) if SPA mode makes it
      redundant
- [ ] 7.6 Point `generate:types` at the offline `openapi.json` from 6.15 and
      extend the CI freshness check to `generated.d.ts`
- [ ] 7.7 Handle 401: treat `me` as signed out, guard the add/edit and "my list"
      routes, and show the sign-in error from 5.5
- [ ] 7.8 Remove scaffold leftovers (`db-collections` demo messages collection)

## 8. Frontend features

- [x] 8.1 Home: mapcn map plus restaurant cards for the current bbox. The bbox
      is a validated search param updated on map move, and hover is synced
      between card and pin
- [ ] 8.2 Wire the navbar search and a tag filter (from `/api/tags`) into the
      list query, and add pagination controls
- [ ] 8.3 Empty states: "nothing in this area" vs "no matches for these filters"
- [ ] 8.4 Restaurant detail page (currently a placeholder): branches on a map,
      tags, price tier, links, reservation flag, rating summary and reviews,
      the viewer's status toggle, and edit/delete for the creator only
- [ ] 8.5 Add/edit form with TanStack Form and Zod mirroring the backend rules:
      branch picker (drop/drag a pin, label, add/remove), tag input suggesting
      existing tags, optional initial status, server 422 errors shown alongside
      client ones
- [ ] 8.6 "My list" view: the user's restaurants filtered by status/tag/search
      in URL state, with a status toggle using an optimistic update that rolls
      back on error
- [ ] 8.7 Reviews: an add-review dialog (from the navbar menu and the detail
      page), and card/detail ratings fed from the real rating summary (the
      card `Rating` is static today)
- [ ] 8.8 Delete with a confirmation dialog and cache invalidation on success

## 9. Container and deployment

- [ ] 9.1 Root multi-stage `Dockerfile`: a bun stage builds the SPA, then a
      Python stage installs `api/` with uv, copies the bundle into `static/`,
      adds the dbmate binary, and runs uvicorn as non-root.
      `api/Dockerfile` and `ui/Dockerfile` remain dev images
- [ ] 9.2 `task build-local`: build the image and run it against the compose
      Postgres with Infisical-injected env
- [x] 9.3 Generate the chart with `helm create` at `infra/helm/resto-tracker/`
- [ ] 9.4 Strip unused scaffold (tests, and whichever of Ingress/HTTPRoute the
      homelab does not use), and set chart metadata
- [ ] 9.5 Add the migration initContainer: same image, runs `dbmate up` with
      `DBMATE_MIGRATIONS_DIR`/`DBMATE_SCHEMA_FILE` pointed at the image's SQL
      paths, requests `cpu: 50m` / `memory: 64Mi`, limits `cpu: 500m` /
      `memory: 256Mi`
- [ ] 9.6 Add `templates/secret.yaml`: an `InfisicalSecret` modelled on
      `~/homelab/lubelogger/templates/secret.yaml`, scoped to the
      `resto-tracker` project, as a `pre-install` hook at weight `-10`,
      managing `<fullname>-secrets`. Consume it via `envFrom.secretRef` and
      expose the identity ID, project slug, and env slug as values
- [ ] 9.7 Set `image.repository: ghcr.io/kvdomingo/resto-tracker`,
      `image.tag: latest`, `imagePullPolicy: Always`, and the Keel
      `deploymentAnnotations` (`keel.sh/policy: force`, `keel.sh/trigger: poll`,
      `keel.sh/match-tag: "true"`) wired through
      `.Values.deploymentAnnotations` as in
      `~/homelab/lubelogger/templates/deployment.yaml`
- [ ] 9.8 Liveness/readiness probes on `/api/health`, and the app resources
      from `design.md` as values
- [ ] 9.9 Configure the HPA (`minReplicas: 2`, `maxReplicas: 5`, 70% CPU) and
      set `strategy.rollingUpdate.maxUnavailable: 0`
- [ ] 9.10 Add the PodDisruptionBudget with `minAvailable: 1`
- [ ] 9.11 Expose the DB pool size from 4.6 as a chart value next to
      `maxReplicas`
- [ ] 9.12 Make sure every value that might need changing under pressure is a
      real entry in `values.yaml`: image tag, replica bounds, resources,
      ingress host, Infisical scope, pool size
- [ ] 9.13 Create the Argo CD Application pointing at the chart and confirm it
      reaches Synced/Healthy
- [ ] 9.14 Observe which field Keel actually patches to force a rollout, then
      add a scoped `ignoreDifferences` for exactly that field. Do not guess the
      path from documentation
- [ ] 9.15 Verify `helm template` output: HPA, PDB, initContainer,
      `InfisicalSecret` hook annotations and weight, Keel annotations

## 10. CI/CD

- [ ] 10.1 Pull-request workflow: backend tests, ruff/ty/sqlfluff, biome and
      `tsc`, a UI build, and the codegen freshness check (apply migrations to a
      scratch Postgres, regenerate sqlc and `generated.d.ts`, fail on any diff)
- [ ] 10.2 Push-to-`main` workflow: build the image and push
      `ghcr.io/kvdomingo/resto-tracker` as `latest` and `sha-<commit>` with
      `GITHUB_TOKEN`
- [ ] 10.3 Gate the push on the same checks as 10.1
- [ ] 10.4 Confirm no cluster credentials exist in any workflow and that CI
      never commits to `infra/`

## 11. Verification

- [ ] 11.1 Full local run from a clean checkout: `task migrate` →
      `task load-fixtures` → `task up` → browse the map anonymously → sign in
      via OAuth and confirm the first page after the redirect already shows you
      as signed in → add a restaurant with two branches and three tags → mark it
      want-to-try, then tried → review it → filter by tag → delete it
- [ ] 11.2 Repeat against `task build-local`, confirming the served bundle
      loads, a deep link like `/restaurants/{id}` refreshes without a 404, and
      an unknown `/api/*` path returns JSON
- [ ] 11.3 Confirm every scenario in `specs/user-auth`,
      `specs/restaurant-catalog`, and `specs/personal-list` has a passing test
- [ ] 11.4 Confirm `task generate` is idempotent on a clean tree and that a
      deliberate field rename in a Pydantic model breaks `tsc`
- [ ] 11.5 Record the app container's CPU and memory during 11.2 and reconcile
      against 9.8
- [ ] 11.6 Confirm two replicas starting together against an unmigrated
      database both come up, with dbmate's advisory lock serialising them
- [ ] 11.7 Confirm Keel has adopted the Deployment and a pushed image triggers a
      rollout
- [ ] 11.8 Confirm that after a Keel rollout the Application returns to
      Synced/Healthy and self-heal does not revert the new pods
- [ ] 11.9 Confirm the incident path: commit `image.tag: sha-<known-good>`,
      watch Argo pin it, revert, and confirm Keel resumes
- [ ] 11.10 Confirm the managed Postgres target has `postgis`, `pg_idkit`,
      `citext`, and `pg_trgm`
- [ ] 11.11 Run `openspec validate --strict` on this change
