## Context

The backend, schema, auth flow, and map browse page are partly built. This
document records the decisions as they stand in the code and the plan for the
rest. See `proposal.md` for motivation and `specs/` for the behaviour being
built.

Four constraints shape the design:

1. **`sqlc-gen-python` owns all database access.** There are no ORM models. The
   schema's source of truth is plain SQL, queries are hand-written SQL compiled
   into typed Python, and anything an ORM would normally hide (identity mapping,
   lazy loading, cascade behaviour) has to be explicit in SQL.
2. **Authentication is external.** Stytch holds credentials and sessions. The
   backend only maps a Stytch user ID to a local row and never sees a password.
3. **The catalogue is shared, the list is personal.** Restaurants, branches,
   tags, and reviews are visible to everyone. Tried / want-to-try statuses
   belong to one user each.
4. **Groups are coming.** They are not in this change, but their tables already
   exist and nothing in the restaurant model has to change to add them.

## Goals / Non-Goals

**Goals:**

- Browsing restaurants by visible map area, backed by a spatial index.
- A personal-list model that already works per user, so adding groups does not
  migrate status data.
- One `task up` gets a working local stack with secrets injected.
- One image to build and ship. The backend serves the frontend, so there is a
  single artifact and a single thing to deploy.
- Deployment works the way the rest of the homelab does: `infra/` is the source
  of truth, Argo CD syncs it, Infisical supplies secrets, and Keel rolls new
  images. No `helm` command ever runs against the cluster.

**Non-Goals:**

- Proximity queries ("near me", distance sort). Bounding-box browse is the only
  spatial query.
- Server-side rendering, offline support, or a mobile app.
- Image uploads.
- Moderation, edit history, or collaborative editing of catalogue entries.

## Decisions

### Repository layout

A single repository producing a single deployable:

```text
api/                     FastAPI app
  app/routers/           Route modules, auto-registered under /api
  app/internals/auth.py  Stytch auth backend and get_user dependency
  app/repositories/sql/  migrations/, queries/, fixtures/, schema.sql (dbmate dump)
  app/repositories/generated/  sqlc output (committed)
  sqlc.yaml
ui/                      TanStack Start (SPA mode) + Router
  src/types/generated.d.ts     openapi-typescript output (committed)
infra/helm/resto-tracker/      Helm chart
docker-compose.yml       Local dev: db, migrations, api, ui
Taskfile.yml             Task runner
mise.toml                Tool versions
```

*Why one repo:* the API contract changes on both sides at once and there is one
developer. Two repositories would buy an independent release cadence nobody
needs and cost a synchronised-PR dance on every schema change.

### Migrations: dbmate, with sqlc reading the dump

Migrations live in `api/app/repositories/sql/migrations/` as timestamped `.sql`
files with `-- migrate:up` / `-- migrate:down` sections, applied by `dbmate`.
dbmate writes the resolved schema to `schema.sql` after every migration, and
that dump is sqlc's schema input.

*Why the dump rather than the migrations directory:* the dump is the schema
after every migration has run, including extension types and the
`restaurant_branch_list` domain, so sqlc never has to replay migration history.
*Consequence:* a migration edited but not yet applied is invisible to sqlc.
Always `task migrate` before regenerating, and commit `schema.sql` with the
migration that changed it.

dbmate is a single static binary, so it drops into the app image and runs as an
initContainer without a language runtime.

*Alternatives:* Alembic was rejected because without SQLAlchemy models its
autogenerate does nothing. Atlas is more capable than needed.

### PostGIS `geography(Point)` for branches

`restaurant_branches.geography` is a `GEOGRAPHY(POINT, 4326)` with a GiST index.
The list endpoint filters with
`geography && ST_MakeEnvelope(w, s, e, n, 4326)`, and lat/lon are extracted with
`ST_Y`/`ST_X` for the response.

*Why PostGIS now:* map-area browse is a requirement, and a bounding-box overlap
on a GiST index is what PostGIS is for. Two `double precision` columns would
need a hand-rolled range filter that cannot use one index for both axes.

*Driver detail:* asyncpg gets a pass-through codec for `geography` on connect,
and geoalchemy2 is loaded as an engine plugin. Points are written as EWKT
(`SRID=4326;POINT(lon lat)`). Note the longitude-first order.

### ULID text primary keys

Every table's `id` is `TEXT DEFAULT idkit_ulid_generate()` from `pg_idkit`.

*Why:* ULIDs are URL-safe, roughly time-sortable (so `ORDER BY id` approximates
creation order without an extra index), and need no client-side generation.
*Cost:* `pg_idkit` is an uncommon extension. See Risks.

### Tags: a shared vocabulary in their own table

`tags(id, name CITEXT UNIQUE, created_by_id)` plus
`restaurant_tags(restaurant_id, tag_id)` with a composite primary key and a
`tag_id` index.

*Why tables rather than `text[]`:* the catalogue is shared, so tags are a shared
vocabulary. The UI suggests existing tags, and two users typing `Ramen` and
`ramen` should land on the same tag. `citext` makes the uniqueness and every
comparison case-insensitive in the database, so the API only trims whitespace
and dedupes before calling get-or-create for each name.

### Branches as a child table

`restaurant_branches(id, restaurant_id, geography, label)` with
`ON DELETE CASCADE`.

*Edit strategy:* on update, delete all of a restaurant's branches and re-insert
the submitted set in the same transaction. Nothing external depends on branch
IDs being stable, and this avoids a diffing algorithm for a list that is
realistically under five items. Branch order is not part of the contract.
Reads order by `id`.

### Shared catalogue, creator-owned writes

`restaurants.created_by_id` references `users` with `ON DELETE SET NULL`, so
deleting an account does not delete catalogue entries others rely on. Update
and delete queries carry `WHERE id = @id AND created_by_id = @user_id`. A miss
is then followed by an existence check that picks `404` or `403`. Restaurant
existence is public, so `403` leaks nothing.

### Personal list: `restaurant_visits`

`restaurant_visits(user_id, restaurant_id, has_visited, created_at)`, with
primary key `(user_id, restaurant_id)` and both FKs `ON DELETE CASCADE`. No row
means not on the list. `has_visited = false` is `want_to_try`, and `true` is
`tried`. The API exposes the enum, and only the queries know about the boolean.

*Why a per-user table from day one:* the catalogue is shared, so status cannot
live on the restaurant row. This is also what groups will need, so status data
does not migrate when groups arrive.

### Reviews

`reviews(id, restaurant_id, author_id, rating 1–5, content, is_anonymous,
created_at)`. `author_id` is `ON DELETE SET NULL` and `restaurant_id` is
`ON DELETE CASCADE`. The rating summary (average, count) is computed in the read
queries with `AVG`/`COUNT`, with no denormalised column to keep in sync. For an
anonymous review, the API omits the author unless the reader is the author.

### Groups: tables only

`groups` and `group_memberships` exist in the initial migration. No query or
endpoint touches them in this change.

### Data access: sqlc over SQLAlchemy's async engine

sqlc uses the `kvdomingo/sqlc-gen-python` fork, which emits pydantic models and
async queriers that execute against a SQLAlchemy `AsyncSession` (asyncpg
underneath). SQLAlchemy is a connection pool and transaction boundary here, not
an ORM. A request-scoped `Queriers` dependency bundles one querier per query
file over one session. Handlers commit explicitly, once per request, so a
multi-table write is atomic.

Branch lists come back from the list query as a JSONB aggregate cast to the
`restaurant_branch_list` domain. A sqlc override maps that domain to
`list[RestaurantBranch]`, so the generated row type is fully typed rather than
`Any`.

*Request models are hand-written.* Routes must not accept sqlc `*Params`
classes as request bodies. Those expose server-owned columns such as
`created_by_id` and `id` to the client. Each write route takes a Pydantic
request model carrying the validation rules from `specs/restaurant-catalog`,
then maps it onto the params.

### Authentication: backend-brokered OAuth, cookie session

```text
GET /api/auth/login     -> Stytch OAuth start URL (UI links to it)
GET /api/auth/callback  -> oauth.authenticate(token); upsert users row;
                           store session_token + session_jwt in signed cookie;
                           303 -> APP_URL
GET /api/auth/logout    -> sessions.revoke; clear cookie; 303 -> APP_URL
GET /api/auth/me        -> current user (401 if anonymous)
```

Starlette's `SessionMiddleware` holds the session in a cookie signed with
`SECRET_KEY` (HTTP-only, 7 days, `Secure` in production).
`AuthenticationMiddleware` with `StytchAuthBackend` runs on every request. If a
session is present, it calls `sessions.authenticate` with the stored JWT, loads
the local user, and grants the `authenticated` scope plus the user's Stytch
roles. `get_user` turns a missing user into `401` and missing scopes into `403`.

*Why backend-brokered rather than the Stytch React SDK:* the browser never
holds a bearer token, nothing Stytch-specific is baked into the frontend
bundle, and the API stays same-origin cookie auth with no token plumbing in the
fetch client.

*Trade-off:* `sessions.authenticate` is a network call to Stytch on every
request that carries a session, so Stytch latency and availability sit on the
hot path. The upgrade path is `sessions.authenticate_jwt`, which verifies the
JWT locally against cached JWKS and only calls Stytch once the JWT's short
lifetime has passed. It is a one-function change in `StytchAuthBackend`, done
if latency shows up.

*Failure handling:* a Stytch rejection clears the cookie and the request
continues as anonymous. A Stytch outage must not clear the cookie. It surfaces
as `503` on endpoints that need a user (`specs/user-auth`).

### User provisioning on first sign-in

The callback upserts the `users` row with
`INSERT ... ON CONFLICT (idp_user_id) DO UPDATE SET email = EXCLUDED.email,
name = EXCLUDED.name RETURNING *`.

*Why upsert:* it is idempotent under two concurrent callbacks for the same new
user and keeps email and name in step with Stytch. A get-then-insert races into
a unique violation.

### API surface

```text
GET    /api/health
GET    /api/auth/{login,callback,logout,me}
GET    /api/restaurants            ?n&e&s&w&page&page_size&q&tag   public, map browse
POST   /api/restaurants            signed in; restaurant + branches + tags (+ optional status)
GET    /api/restaurants/{id}       public; + viewer's status when signed in
PATCH  /api/restaurants/{id}       creator only
DELETE /api/restaurants/{id}       creator only
PUT    /api/restaurants/{id}/status    signed in; {status}
DELETE /api/restaurants/{id}/status    signed in; remove from list
GET    /api/me/restaurants         ?status&tag&q   signed in; personal list
GET    /api/restaurants/{id}/reviews   public
POST   /api/restaurants/{id}/reviews   signed in
PATCH  /api/reviews/{id}           author only
DELETE /api/reviews/{id}           author only
GET    /api/tags                   public; all tags
```

Paginated responses use `Paginated[T]` (`data` plus `meta` with `page`,
`page_size`, `page_count`, and `total_count`). Every route declares an explicit
`response_model` so the generated frontend types are exact.

Free-text search uses `ILIKE` over restaurant name and branch labels. `pg_trgm`
is installed so a trigram GIN index can back it if the catalogue grows.

### One image: FastAPI serves the built SPA

The UI is TanStack Start configured in **SPA mode**, so `vite build` emits
static assets and an `index.html` shell rather than a nitro server. A single
multi-stage `Dockerfile` builds the UI with bun, then copies the output into the
Python runtime stage's `static/`. In production, FastAPI serves it with
`app.frontend("/", directory="static", fallback="index.html")`, registered
*after* the `/api` routers so an unknown API path still returns a JSON `404`.

nitro stays in the dev toolchain only, where its dev proxy forwards `/api/**` to
the `api` container. That keeps dev same-origin, so the session cookie works and
no CORS is configured anywhere.

*Why one image:* frontend and backend version together, deploy together, and
roll back together. There is no scenario in this app where one is deployed
without the other.

*Consequences:*

- **Same origin everywhere**, so the frontend calls the relative `/api` path.
- **Nothing is baked into the bundle.** Auth is server-side, and the bundle
  holds no Stytch or API configuration.
- **Static asset caching:** Vite emits content-hashed filenames, which get a
  long `max-age`, while `index.html` is served `no-store` so a deploy is picked
  up immediately.

*Alternative rejected:* running the nitro/bun server as a second container adds
a runtime and a deployment only to do what a static mount does at this traffic
level.

### Types are generated end to end

```text
migrations --dbmate--> schema.sql --sqlc--> Python row/param models
FastAPI + Pydantic --app.openapi()--> openapi.json
openapi.json --openapi-typescript--> ui/src/types/generated.d.ts
generated.d.ts --openapi-fetch / openapi-react-query--> typed $api hooks
```

Both generated outputs are committed. The repo builds without the codegen
toolchains, contract changes show up in diffs, and CI regenerates and fails on
any diff.

`generate-api-types` currently reads `openapi.json` from the running dev
server. For CI it has to work cold: a `task generate:openapi` script imports
the app and dumps `app.openapi()` without starting a server, and
`generate:types` reads that file.

*Still hand-written:* the Zod schemas behind the add/edit form, which mirror the
backend's rules. A rule change on one side is not caught at compile time. The
form will just be stricter or looser than the server, which stays authoritative
with its `422`.

### Frontend

- **TanStack Query** owns all server state, reached only through the
  `openapi-react-query` `$api` hooks.
- **URL state:** filters, pagination, and the map's bounding box are TanStack
  Router search params validated with Zod. Page, page size, and search are
  declared on the root route so every page inherits them, and route-specific
  params such as `bbox` are declared on their route. Filter state is shareable,
  survives refresh, and becomes the query key for free.
- **TanStack Form** for the add/edit form, with Zod schemas mirroring the
  backend's rules.
- **shadcn/ui + Tailwind v4** for components, copied into the repo.
- **mapcn** for maps (MapLibre GL). Tiles use Carto basemaps (mapcn's default
  light/dark styles), with the style overridable per map. The same component
  drives the browse map, the detail map, and the branch picker
  (`{label, latitude, longitude}[]`).

### Local development

`task up` wraps `docker compose up --watch` in `infisical run`, passing an
Infisical token into the containers. The `api` and `ui` containers each run
`infisical run --watch` around their dev server, so secrets come from the
`resto-tracker` project with no `.env` holding real values. Services:

- `db`: `ghcr.io/kvdomingo/postgresql-pig:18` (Postgres 18 with PostGIS,
  pg_idkit, citext, pg_trgm), named volume, healthcheck.
- `migrations`: one-shot dbmate in the `admin` profile, run by `task migrate` /
  `task unmigrate`. `task load-fixtures` loads `sql/fixtures/` (a system user
  and sample restaurants with branches and tags).
- `api`: `fastapi dev` with reload, source bind-mounted. It restarts when
  `pyproject.toml` or `uv.lock` change.
- `ui`: `bun run dev` with HMR and the nitro `/api` proxy. It restarts when
  `package.json` or `bun.lock` change.

Codegen is run by hand today (`sqlc generate`, `bun run generate-api-types`).
A `task generate` target, plus `develop.watch` `sync+exec` hooks that
regenerate `openapi.json` and then `generated.d.ts` when routers or models
change, are planned in tasks.

Dev runs two processes while production runs one image. A `task build-local`
target builds and runs the production image against the compose Postgres, so
the served-SPA path is one command away.

### Deployment: `infra/` is the source of truth, Argo CD syncs it

One image, one Helm chart in `infra/helm/resto-tracker/`: a single Deployment
and Service running uvicorn, with an Ingress sending every path to it. `/api`
is handled by the API routes and everything else falls through to the SPA.

**No `helm` command ever runs against the cluster.** An Argo CD Application
points at the chart in this repository, and Argo renders and applies it.

- **There is no `helm install`, `helm upgrade`, or `helm rollback`.** A config
  rollback is `git revert`.
- **`--set` does not exist.** Every value that might need changing under
  pressure has to be a real value in `values.yaml`.
- **Helm hooks still work, but as Argo hooks.** `helm.sh/hook: pre-install`
  becomes `PreSync`, and `helm.sh/hook-weight` becomes a sync-wave.
- **`helm template` is still useful** as a local rendering check.

The chart was generated with `helm create`, so `_helpers.tpl`, labels, Service,
Ingress, HTTPRoute, ServiceAccount, and HPA come from the upstream scaffold.
Only the PDB, the `InfisicalSecret`, and the initContainer are added on top.

Postgres in production is a managed instance, not a chart dependency. Running a
database in the same chart as the app couples their lifecycles in exactly the
way that turns an app rollback into a data incident.

### Argo CD and Keel both write to the Deployment

Argo CD reconciles the Deployment toward git, and Keel mutates it to force a
rollout when a new digest appears behind `latest`. With `selfHeal` enabled,
Argo would revert Keel's change, and the new image would either never land or
land and get rolled back.

The image field does not drift. What drifts is the pod-template annotation Keel
sets to force a new ReplicaSet. An `ignoreDifferences` entry on the
Application, scoped to exactly that field, stops Argo treating it as drift while
everything else stays under self-heal. The exact path depends on the Keel
version in the cluster, so it is observed rather than guessed (task 9.14).

### Secrets: Infisical, not chart values

An `InfisicalSecret` (`secrets.infisical.com/v1alpha1`) materialises
`<fullname>-secrets`, consumed via `envFrom.secretRef`. It holds `DATABASE_URL`,
`SECRET_KEY`, `STYTCH_PROJECT_ID`, `STYTCH_PUBLIC_TOKEN`,
`STYTCH_SECRET_TOKEN`, `STYTCH_CALLBACK_URL`, and `APP_URL`. The chart
references the project and environment slug, never the values. `PYTHON_ENV` is
a plain env var in the chart.

It carries the same annotations as the rest of the homelab's charts:

```yaml
annotations:
  helm.sh/hook: pre-install
  helm.sh/hook-weight: "-10"
  helm.sh/hook-delete-policy: before-hook-creation
```

**The weight must stay the lowest in the chart.** Everything else depends on
the Secret, and any hook added later takes a weight strictly greater than `-10`.

Being first in the wave guarantees the CR is created first, not that the Secret
exists, because the operator reconciles asynchronously. A pod in that window
sits in `CreateContainerConfigError` and the kubelet retries until the Secret
appears. A hook Job with a low `backoffLimit` would give up first, which is one
reason migrations run as an initContainer.

### Migrations run as an initContainer, not a sync hook

An initContainer on the app pod runs `dbmate up` from the same image before
uvicorn starts.

*Why not a PreSync hook:* **Keel updates the Deployment directly, without a git
commit, so Argo never syncs and no PreSync hook fires.** The most common deploy
would skip migrations. Tying them to the pod lifecycle means they run on every
rollout, whatever triggered it.

*Safe with `minReplicas: 2`:* dbmate takes a Postgres advisory lock, so
concurrent initContainers serialise.

*What it demands:* migrations must be backward-compatible with the running
code, because during a rolling update new pods migrate while old pods still
serve. Additive changes are safe. Removals need expand/contract across two
releases.

### Image tag `latest`, rolled by Keel

The image is `ghcr.io/kvdomingo/resto-tracker:latest` with
`imagePullPolicy: Always`, and Keel watches it via `deploymentAnnotations`:

```yaml
deploymentAnnotations:
  keel.sh/policy: force
  keel.sh/trigger: poll
  keel.sh/match-tag: "true"
```

`force` plus `match-tag` is the only way to detect a new digest behind an
unchanging tag. There is no per-workload `pollSchedule`, so the cluster default
applies.

*Cost:* **git does not record what is running.** Recovery from a bad build is
roll-forward. *Mitigation:* CI also pushes an immutable `sha-<commit>` tag.
During an incident, committing `image.tag: sha-<good>` pins a known-good build,
and reverting that commit unpins it.

### CI/CD: GitHub Actions builds, Keel deploys

On pushes to `main`, a workflow builds the image and pushes it as both `latest`
and `sha-<commit>`. It never talks to the cluster, and there is no build-time
configuration to pass in. Code changes go `main` → image → Keel → pods.
Deployment changes go `infra/` → git → Argo → cluster. CI never commits back
to `infra/`.

The push is gated on the pull-request checks: tests, lint/typecheck, and the
codegen freshness check over both the sqlc output and `generated.d.ts`.

### Scaling, disruption, and resources

| Setting | Value |
| --- | --- |
| HPA | `minReplicas: 2`, `maxReplicas: 5`, target 70% CPU utilisation |
| PDB | `minAvailable: 1` |
| App requests | `cpu: 100m`, `memory: 256Mi` |
| App limits | `cpu: 1000m`, `memory: 512Mi` |
| Migration initContainer | requests `cpu: 50m` / `memory: 64Mi`, limits `cpu: 500m` / `memory: 256Mi` |

- *`minAvailable: 1` against a floor of 2* leaves the cluster room to evict
  during a drain.
- *A floor of 2* is the cheapest number that survives losing a pod.
- *Requests far below limits* keep the HPA's CPU ratio meaningful for a
  mostly-idle app, while leaving burst room.
- *Memory limit 2× request:* a leak becomes a restarted pod, not node pressure.

**Connection budget.** SQLAlchemy's default pool is 5 connections plus 10
overflow per pod, so 15 per pod and 75 at `maxReplicas: 5`. That is too close to
a small managed instance's limit of about 100. The engine's `pool_size` and
`max_overflow` become settings, defaulting to 10 total per pod (50 at the
ceiling), and are exposed as chart values next to `maxReplicas`.

**Nothing blocks running multiple replicas.** Sessions are in signed cookies,
so every replica must share `SECRET_KEY`, which they do because it comes from
the same Infisical secret. Everything else is in Postgres or at Stytch.
Rollouts use `maxUnavailable: 0`.

## Risks / Trade-offs

- **Stytch is on every authenticated request.** A Stytch outage or slowdown
  degrades every signed-in page. → Outages surface as `503` without clearing
  the cookie. Anonymous browsing is unaffected. `authenticate_jwt` local
  verification is a one-function upgrade.
- **`SameSite=strict` session cookie and the OAuth redirect.** The callback is
  reached by a cross-site navigation from Stytch, and the follow-up 303 to
  `APP_URL` is still part of that cross-site chain. Browsers may withhold a
  strict cookie on that first page load, so the user looks signed out until
  they navigate. → Verify in task 11.1. If it shows, `lax` is the standard
  setting for OAuth-backed session cookies.
- **`pg_idkit` on managed Postgres.** Few managed providers ship it, and every
  `id` default depends on it. → Confirm the target instance supports it before
  first deploy. The fallback is a migration that swaps the defaults to
  `gen_random_uuid()::text` or an app-side ULID. Existing IDs are text and stay
  valid.
- **PostGIS on managed Postgres.** It is widely available, but it is an
  extension to enable. → Same pre-deploy check.
- **`sqlc-gen-python` is a personal fork of an experimental plugin.** →
  Generated code is committed, so a broken plugin only blocks regeneration. The
  queries are simple enough to hand-maintain in the worst case.
- **sqlc reads `schema.sql`, not the migrations.** A migration that was never
  applied locally leaves sqlc generating against an old schema. → `task
  generate` runs after `task migrate`, and the CI freshness check applies
  migrations to a scratch database first.
- **No ORM means hand-written authorization predicates.** A missing
  `created_by_id = @user_id` or `user_id = @user_id` is the highest-severity bug
  class here. → All queries live in `sql/queries/`, and the access-rule
  scenarios in `specs/user-auth` become tests against every write endpoint.
- **The shared catalogue has no moderation.** Anyone signed in can add
  restaurants and tags, and a bad tag is visible to all. → Acceptable for a
  small trusted user base. Stytch roles already flow into auth scopes if an
  admin override is needed.
- **One image couples frontend and backend releases.** → Both are cheap to
  rebuild, and the SPA mount is the only coupling point if they ever split.
- **Dev runs two processes, production runs one image.** → `task build-local`,
  exercised in task 11.2.
- **Generated frontend types are only as good as the OpenAPI document.** →
  Explicit `response_model` on every route, and contract assertions in 6.13.
- **`latest` plus Keel means git does not record the running version.** →
  `sha-<commit>` tags for pinning, and Keel notifications as the deploy record.
- **Argo self-heal and Keel both write to the Deployment.** → A scoped
  `ignoreDifferences`, verified against the running Keel version (9.14).
- **Migrations in an initContainer run during a rolling update.** →
  Additive-only, with expand/contract for removals. This is a review discipline,
  not enforced.
- **The Infisical operator is in the startup path, and so is Infisical in
  dev.** → Running pods keep their injected env, so an outage blocks deploys,
  not traffic. Locally, `task up` needs Infisical reachable.
- **Resource numbers are estimates.** → Chart values, checked in task 11.5.

## Migration Plan

First deployment, so there is nothing to migrate from:

1. Provision managed Postgres 18 and confirm `postgis`, `pg_idkit`, `citext`,
   and `pg_trgm` are available. Create the database.
2. Configure Stytch live and test projects with the OAuth provider and redirect
   URLs. Put the secrets listed above in the `resto-tracker` Infisical project.
3. Push the first image so `ghcr.io/kvdomingo/resto-tracker:latest` exists.
4. Create the Argo CD Application pointing at `infra/helm/resto-tracker/` and
   sync it. The `InfisicalSecret` lands first, the operator materialises the
   Secret, and the pods' initContainers run `dbmate up`.
5. Confirm Keel has adopted the Deployment and Argo is not reverting its
   rollouts before relying on automated deploys.

**Rollback is roll-forward.** Reverting `infra/` rolls back configuration, not
code. Recover from a bad build by pushing a good image or committing
`image.tag: sha-<good>`. Schema rollback is `dbmate rollback`. Every migration
in this change is additive, so reverting the app without the schema is safe.

## Open Questions

- Where the Argo CD `Application` manifest lives: in this repository or in the
  homelab's app-of-apps root. The chart is the same either way.
- Whether a user may post more than one review per restaurant. The schema allows
  it today. A `UNIQUE (restaurant_id, author_id)` is a one-line additive
  migration if not.
