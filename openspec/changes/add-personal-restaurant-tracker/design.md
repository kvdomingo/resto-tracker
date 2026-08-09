## Context

Greenfield repository — nothing exists yet, so every decision below is a first
choice rather than a migration. See `proposal.md` for motivation and `specs/`
for the behaviour being built.

Three constraints shape the design:

1. **`sqlc-gen-python` owns all database access.** No ORM. That means the
   schema's source of truth is plain SQL, queries are hand-written SQL compiled
   into typed Python, and anything an ORM would normally hide (identity mapping,
   lazy loading, cascade behaviour) has to be explicit in SQL.
2. **Authentication is external.** Stytch holds credentials and sessions; the
   backend only maps a Stytch user ID to a local row. The backend never sees a
   password.
3. **Groups are coming.** They are not in this change, but the ownership model
   has to be shaped so adding them later is an additive migration, not a
   rewrite.

## Goals / Non-Goals

**Goals:**

- A schema whose ownership column can grow a group dimension without rewriting
  the restaurant tables.
- Session verification that does not add a network round-trip to Stytch on every
  request.
- One `docker compose up` gets a working local stack, including migrations and
  codegen.
- One image to build and ship — the frontend is served by the backend, so there
  is a single artifact and a single thing to deploy.
- Deployment works the way the rest of the homelab does: `infra/` is the source
  of truth, Argo CD syncs it, Infisical supplies secrets, and Keel rolls new
  images. No `helm` command ever runs against the cluster.

**Non-Goals:**

- Geospatial querying (proximity, bounding-box, "near me"). Coordinates are
  stored and rendered, not queried against.
- Server-side rendering, offline support, or a mobile app.
- Multi-tenancy beyond per-user ownership.
- Image uploads. `image_url` is a URL the user supplies; the app hosts nothing.

## Decisions

### Repository layout

A single repository producing a single deployable:

```text
backend/             FastAPI app, sql/ (migrations + queries), generated/ (sqlc output)
frontend/            Vite + React; its build output is copied into the image
infra/               Helm chart
Dockerfile           One image: builds the frontend, then serves it from the backend
docker-compose.yaml  Local dev: postgres + backend + frontend dev server
Taskfile.yaml        Task runner: codegen, builds, local workflows
sqlc.yaml            Codegen config, at the root so both sql/ trees are visible
```

*Why one repo:* the API contract changes on both sides at once and there is one
developer. Two repositories would buy independent release cadence nobody needs
and cost a synchronised-PR dance on every schema change.

### Migrations: dbmate

Schema lives in `backend/sql/migrations/` as timestamped `.sql` files with
`-- migrate:up` / `-- migrate:down` sections, applied by `dbmate`.

*Why:* sqlc reads migration directories directly as its schema input and
understands dbmate's comment markers, so there is exactly one definition of the
schema and no drift. dbmate is a single static binary with no runtime, so it
drops into the app image and runs as an initContainer without dragging a
language runtime along.

*Alternatives:* Alembic was rejected — without SQLAlchemy models its
autogenerate feature (its main draw) does nothing, leaving a Python dependency
that only executes raw SQL. Atlas is more capable than needed. Hand-applied SQL
was rejected outright: production needs a record of what ran.

### No PostGIS; latitude/longitude as `double precision`

Locations store `lat` and `lon` as two `double precision` columns.

*Why:* no requirement in `specs/` asks a spatial question. PostGIS means a
non-default Postgres image locally and a managed-instance extension in
production, in exchange for capability nothing uses.

*Upgrade path:* if proximity search is ever wanted, add a generated
`geography(Point)` column and a GiST index in one migration. The stored values
do not change.

### Tags as `text[]` on the restaurant row

Tags are a `text[] NOT NULL` column with a GIN index, not a `tags` table plus a
join table.

*Why:* the specs require exactly three things from tags — store them per
restaurant, filter by one, and list a user's distinct tags. A GIN index handles
`tags @> ARRAY[$1]` for the filter, and
`SELECT DISTINCT unnest(tags) ... WHERE owner = $1` handles the list. Two tables
and a join buy rename-a-tag-everywhere and per-tag metadata, neither of which is
specified. Normalising is a small additive migration later if tags grow
attributes.

Normalisation (trim, lowercase, dedupe) happens in the API layer before insert,
so the stored array is already canonical and reads need no cleanup.

*Trade-off:* renaming a tag across many restaurants becomes an `array_replace`
UPDATE over the user's rows rather than a single-row update. Acceptable at
personal-collection scale.

### Locations as a child table with explicit ordinal

`restaurant_locations(id, restaurant_id, label, lat, lon, ordinal)` with
`ON DELETE CASCADE`, unique on `(restaurant_id, ordinal)`.

*Why not a JSONB column:* locations have their own validation rules and the spec
requires order to survive a round-trip. A real table gets column-level
constraints (`CHECK (lat BETWEEN -90 AND 90)`) that the database enforces
regardless of which code path writes.

*Why an explicit ordinal:* row order is not guaranteed without an `ORDER BY`,
and the spec requires submitted order to be preserved.

*Edit strategy:* on update, delete all of a restaurant's locations and re-insert
the submitted set inside one transaction. Location IDs are not exposed in the
API, so nothing external depends on their stability, and this avoids a diffing
algorithm for a list that is realistically under five items.

### Ownership: nullable `group_id` reserved from day one

```sql
restaurants (
  id           uuid primary key,
  owner_id     uuid not null references users(id) on delete cascade,
  group_id     uuid,          -- always NULL in this change; FK added with the groups migration
  ...
)
```

Every query filters `WHERE owner_id = $1 AND group_id IS NULL`. When groups
arrive, the migration adds the `groups` table, the FK constraint, and a
membership check to the filter — no data backfill, no rewrite of existing rows.

*Why reserve the column now:* adding a nullable column later is also cheap, but
reserving it forces every query written today to carry the `group_id IS NULL`
predicate. Retrofitting that predicate across a dozen hand-written SQL queries
is exactly the kind of miss that leaks one user's data into another's list.

**Known future migration:** `status` (tried / want-to-try) currently lives on
the restaurant row, which is correct while a restaurant has exactly one owner.
Under group sharing, status becomes per-user-per-restaurant and must move to its
own table. This is called out here so it is a planned migration rather than a
surprise. It is not pre-built: a join table today would add a join to every read
for a column that has exactly one owner.

### Session verification: local JWT check, Stytch call only on cache miss

The frontend uses Stytch's React SDK for the sign-in UI and holds the session.
Every API request carries the Stytch session JWT as
`Authorization: Bearer <jwt>`. The backend verifies that JWT locally against
Stytch's cached JWKS.

*Why:* Stytch session JWTs are short-lived (~5 minutes) and locally verifiable.
Calling `sessions.authenticate` over the network on every request would put a
third-party API on the critical path of every page load. Local verification
keeps Stytch out of the hot path while the short JWT lifetime bounds how long a
revoked session can survive — the frontend SDK refreshes the JWT, and a revoked
session fails to refresh.

*Where the network call remains:* the JWKS fetch (cached, refreshed on unknown
key ID) and the initial sign-in exchange. The `503` behaviour in
`specs/user-auth` applies to those.

*Alternative rejected:* per-request `sessions.authenticate` — correct and
simpler, but every request inherits Stytch's availability and latency.

### User provisioning on first sign-in

The first authenticated request for an unknown Stytch user ID inserts a `users` row via
`INSERT ... ON CONFLICT (stytch_user_id) DO UPDATE SET email = EXCLUDED.email RETURNING *`.

*Why upsert rather than a dedicated signup endpoint:* Stytch already ran the
signup flow. A separate endpoint would be a second thing to keep in sync and a
race the frontend has to sequence. The upsert is idempotent under concurrent
first requests and keeps the email in step with Stytch.

### API surface

```text
GET    /api/me                    current user, provisioning on first call
GET    /api/restaurants           ?status=&tag=&q=   list + filters
POST   /api/restaurants           create
GET    /api/restaurants/{id}      detail
PATCH  /api/restaurants/{id}      edit (incl. status change)
DELETE /api/restaurants/{id}      delete
GET    /api/tags                  distinct tags for filter chips
```

Status changes go through `PATCH` rather than a dedicated `/status` endpoint —
one write path, one set of ownership checks.

Pydantic models handle request validation (`specs/restaurant-catalog` — name
length, URL scheme, coordinate ranges, non-empty lists), so a `422` with field
paths comes from FastAPI for free. Database `CHECK` constraints mirror the
coordinate and non-empty-name rules as a backstop.

### Writes are transactional

Creating or editing a restaurant touches the restaurant row and its locations.
Both run in one `asyncpg` transaction so a failed location insert cannot leave a
restaurant with none — which the spec forbids.

### One image: FastAPI serves the built frontend

A single multi-stage `Dockerfile` — a Node stage runs `vite build`, and the
Python runtime stage copies the resulting `dist/` in. FastAPI mounts it as
static files with an SPA catch-all that returns `index.html` for any unmatched
path. The mount is registered *after* the `/api` routes so that an unknown API
path still returns a JSON `404` rather than the HTML shell.

*Why one image:* frontend and backend version together, deploy together, and
roll back together. Two images means two tags to keep in step and a window where
a new frontend is talking to an old API. There is no scenario in this app where
one is deployed without the other, so independent deployability is a cost with
no matching benefit.

*Consequences worth naming:*

- **Same origin in production**, so the frontend calls the API at the relative
  path `/api` and no CORS configuration is needed there. CORS stays configured
  for local development only, where Vite serves on a different port.
- **The API base URL no longer needs baking into the bundle** — it is relative.
  Only Stytch's public token is a build-time value.
- **Static asset caching** is the backend's job: Vite emits content-hashed
  filenames, which get a long `max-age`, while `index.html` is served `no-store`
  so a deploy is picked up immediately.

*Alternative rejected:* nginx serving the bundle in a second container or a
second Deployment. It adds a component to configure, monitor, and patch in order
to do what FastAPI's `StaticFiles` does in three lines at this traffic level.

### Types are generated end to end

Nothing about the data's shape is typed by hand at a boundary:

```text
sql/migrations/*.sql  --sqlc-->                Python row classes
FastAPI + Pydantic    --app.openapi()-->       openapi.json
openapi.json          --openapi-typescript-->  frontend/src/api/schema.d.ts
schema.d.ts           --openapi-fetch-->       typed client
client                --openapi-react-query--> typed useQuery / useMutation hooks
```

`openapi-fetch` gives a thin typed wrapper over `fetch` where the path, the
params, and the response are all inferred from the schema. `openapi-react-query`
layers TanStack Query on top of it, so a hook call is checked against the real
endpoint rather than against a hand-written interface that drifts.

*Why generate rather than hand-write:* the highest-frequency change in this app
is a field being added to or renamed on a restaurant. Hand-written frontend
types make that a silent runtime bug found by a user; generated ones make it a
build failure found by `tsc`. Since the backend already produces an accurate
OpenAPI document from the Pydantic models, hand-maintaining a second copy is
work that only creates opportunities to be wrong.

*Extraction is offline.* `openapi.json` is dumped by a small script that imports
the app and calls `app.openapi()` — no server needs to be running, so codegen
works in CI and in a cold checkout.

*Committed, like the sqlc output,* and for the same reasons: the repo builds
without the codegen toolchain, contract changes show up in diffs, and CI
verifies freshness by regenerating and failing on any diff. `task generate` runs
both chains.

*What is still hand-written:* the Zod schemas behind the add/edit form. OpenAPI
carries the field shapes but not a usable client-side validator, so form rules
are written to mirror the backend's. Generated types catch a shape change at
compile time; a rule change (say, the name limit moving from 200 to 300) will
not be caught, and the form will simply be stricter than the server until
someone notices. That is a UX bug, not a correctness one — the server stays
authoritative and the 422 path is always live.

### Frontend

- **TanStack Query** owns all server state, reached through
  `openapi-react-query` so query keys and response types come from the schema.
  No Redux, no context-based store; there is no client state that is not either
  a form value or a URL parameter.
- **Filters live in the URL** as search params. This makes filter state
  shareable and bookmarkable, survives refresh, and gives TanStack Query a
  natural cache key — free, versus a state atom.
- **TanStack Form** for the add/edit form, with Zod schemas mirroring the
  backend's validation rules so users see errors before a round-trip. The
  backend still validates; the frontend copy is UX, not enforcement.
- **shadcn/ui + Tailwind** for components. Copied into the repo, not installed,
  per shadcn's model.
- **mapcn** for the map — shadcn-style map components over MapLibre GL, used
  both for the location picker (drop a pin, type a label) and the detail-view
  pins. Tiles come from OpenFreeMap's free public style — no API key, no
  account, no usage tier. The style URL stays configuration, so swapping to a
  paid provider later is an env var rather than a code change.

  *Contingency:* if mapcn's component set does not cover pin-dropping, fall back
  to MapLibre GL directly with a shadcn-styled wrapper. This is a
  component-library choice, not an architectural one — the interface to the rest
  of the app is `{label, lat, lon}[]` either way.

### Local development

`docker-compose.yaml` brings up Postgres 18, the backend (uvicorn with reload,
source bind-mounted), and the frontend (Vite dev server with HMR, proxying
`/api` to the backend). A one-shot `migrate` service runs dbmate before the
backend starts.

**Codegen fires on save via `develop.watch`.** Editing a route should not leave
the frontend's types stale until someone remembers to regenerate, so the watch
block chains the two codegen stages, each running in the container that has the
right toolchain:

```yaml
backend:
  develop:
    watch:
      - path: ./backend/app/routers      # and ./backend/app/schemas
        action: sync+exec
        exec: { command: ["task", "generate:openapi"] }   # -> backend/openapi.json
      - path: ./backend/pyproject.toml
        action: rebuild
frontend:
  develop:
    watch:
      - path: ./backend/openapi.json     # written by the stage above
        action: sync+exec
        exec: { command: ["task", "generate:types"] }     # -> frontend/src/api/schema.d.ts
      - path: ./frontend/package.json
        action: rebuild
```

*Why two stages rather than one:* `openapi-typescript` is a Node tool and the
backend dev image is Python. Splitting on `openapi.json` puts each step where
its toolchain already lives instead of installing Node into the backend image to
save a hop.

*Why `schemas/` is watched as well as `routers/`:* response models are Pydantic
classes, and the generated types change when a model changes even if no route
does. Watching only `routers/` would miss the most common edit.

Both source trees stay bind-mounted, so generated files land on the host where
they can be committed and where Vite's HMR picks up the new `schema.d.ts`
immediately. This requires the `task` binary in both dev images — a single
static Go binary, the same argument that put dbmate in the app image.

Note the asymmetry this creates: development runs two processes, production runs
one image with FastAPI serving the built bundle. That gap can hide a bug that
only appears in the served build — a wrong base path, a missing SPA fallback
route. A `task build-local` target builds and runs the production image against
the same Postgres, so the production path is one command away rather than
something only CI ever exercises.

Codegen is **not** run in the container on every start — `task generate` runs
both chains (sqlc after editing SQL, `openapi.json` plus `openapi-typescript`
after changing a route or a Pydantic model) and the output is committed.
*Why commit generated code:* it makes the repo runnable without the sqlc or Node
toolchains, it makes query and contract changes visible in diffs and review, and
it keeps CI from needing a codegen step before it can run tests. CI verifies the
committed output is current by regenerating and failing on any diff.

Local dev points at a Stytch **test** project. Without Stytch credentials the
app cannot be signed into at all, so `README` setup instructions start there.

### Deployment: `infra/` is the source of truth, Argo CD syncs it

One image, one Helm chart in `infra/`: a single Deployment and Service running
uvicorn, with an Ingress sending every path to it — `/api` handled by the API
routes, everything else falling through to the SPA. No path-splitting rules, no
second backend for the ingress to route between.

**No `helm` command ever runs against the cluster.** An Argo CD Application
points at `infra/` in this repository; Argo renders the chart itself and applies
the result. The consequences are worth being explicit about, because several
habits stop working:

- **There is no `helm install`, `helm upgrade`, or `helm rollback`.** Changing
  anything deployed means committing to `infra/` and letting Argo sync. A config
  rollback is `git revert`.
- **`--set` does not exist.** Every value that might need changing under
  pressure has to be a real value in `infra/values.yaml`, not a flag someone
  remembers at 3am.
- **Helm hooks still work, but as Argo hooks.** Argo CD translates
  `helm.sh/hook: pre-install` into a `PreSync` phase and `helm.sh/hook-weight`
  into `argocd.argoproj.io/sync-wave`, which is why the `InfisicalSecret` below
  keeps the same annotations as the rest of the homelab's charts.
- **`helm template` is still useful** — as a local rendering check before
  committing. That is a developer command, not a deploy path.

Stytch's public token is baked into the bundle at image build time as a Vite env
var, so changing Stytch projects means a rebuild. Acceptable: it is a public
value that changes roughly never.

Chart values cover the ingress host, the Infisical scope, and every number in
the scaling block below. The chart is generated with `helm create` rather than
hand-written, so the standard `_helpers.tpl`, label conventions, Service,
Ingress, ServiceAccount, and HPA come from the upstream scaffold; only the PDB,
the `InfisicalSecret`, and the initContainer are added on top. Hand-rolling
those templates means re-deriving naming and label helpers that the scaffold
already gets right.

Postgres in production is a managed instance, not a chart dependency. Running a
database in the same chart as the app it serves couples their lifecycles in
exactly the way that turns an app rollback into a data incident.

### Argo CD and Keel both write to the Deployment

Two controllers now have opinions about the same object: Argo CD reconciles it
toward git, and Keel mutates it to force a rollout when a new digest appears
behind `latest`. With `selfHeal` enabled, Argo will revert whatever Keel just
did and the new image never lands — or worse, lands and is rolled back minutes
later, intermittently.

The image field itself does not drift: git says `latest` and Keel keeps it
`latest`. What drifts is whatever Keel mutates to force a new ReplicaSet — a
pod-template annotation. The fix is an `ignoreDifferences` entry on the
Application covering that field, so Argo stops treating Keel's change as drift
while still reconciling everything else.

*Why not just disable `selfHeal`:* that would give up drift correction for the
entire application to work around one field. Scoping the exemption to the field
Keel touches keeps the rest honest.

The exact JSON path depends on the Keel version running in this cluster, so task
9.14 is to observe what Keel actually patches and write the matching
`ignoreDifferences` — not to guess it from documentation.

### Secrets: Infisical, not chart values

An `InfisicalSecret` resource (`secrets.infisical.com/v1alpha1`) materialises a
Kubernetes Secret named `<fullname>-secrets`, which the Deployment consumes via
`envFrom.secretRef`. `DATABASE_URL`, `STYTCH_PROJECT_ID`, and `STYTCH_SECRET`
live in an Infisical project called `resto-tracker`; the chart references the
project and environment slug, never the values.

It carries the same annotations as the rest of the homelab's charts:

```yaml
annotations:
  helm.sh/hook: pre-install
  helm.sh/hook-weight: "-10"
  helm.sh/hook-delete-policy: before-hook-creation
```

**The weight is deliberately the lowest in the chart, and must stay that way.**
Under Argo CD the weight becomes a sync-wave, and everything else in the chart
depends on the Secret existing — so this resource has to be created before any
other hook, not merely early. `-10` leaves room to add hooks between it and the
main sync without ever needing to renumber this one downward. Any hook added
later takes a weight strictly greater than this.

*What the ordering does and does not buy:* being first in the wave guarantees
the CR is created first; it does not guarantee the Secret exists, because the
operator reconciles asynchronously. Anything consuming `<fullname>-secrets`
still has to tolerate it being absent for the first few seconds of a fresh
install. A pod in that window sits in `CreateContainerConfigError` and the
kubelet retries, so it self-heals within roughly one resync interval — but a
hook Job with a low `backoffLimit` would give up first. That is the main reason
migrations run as an initContainer (below) rather than as a hook racing the
operator.

### Migrations run as an initContainer, not a sync hook

An initContainer on the app pod runs `dbmate up` from the same image before
uvicorn starts.

*Why not the PreSync hook Job that would otherwise be obvious:* **Keel updates
the Deployment directly — it is not a git commit, so Argo never syncs and no
PreSync hook fires.** The most common deploy in this setup is exactly the one
that would skip migrations: a new image appears, Keel rolls the pods, and new
code starts against an old schema, silently. Tying migrations to the pod
lifecycle instead means they run on every rollout regardless of what triggered
it — an Argo sync, a Keel update, a node drain, or a manual pod delete.

*Why this is safe with `minReplicas: 2`:* dbmate takes a Postgres advisory lock
before applying anything, so concurrent initContainers across replicas serialise
— the first applies, the rest block briefly and find nothing to do.

*What it demands in return:* migrations must be backward-compatible with the
currently running code. During a rolling update the new pod migrates while old
pods still serve, so a destructive change (dropping a column the old code still
selects) breaks the old pods mid-rollout. Additive changes are safe; removals
need the expand/contract two-release dance. Every migration in this change is
additive, so nothing here is affected — but the constraint is permanent from now
on.

### Image tag `latest`, rolled by Keel

The image is `ghcr.io/kvdomingo/resto-tracker:latest` with
`imagePullPolicy: Always`, and Keel watches for a new digest via
`deploymentAnnotations`:

```yaml
deploymentAnnotations:
  keel.sh/policy: force          # redeploy when the digest behind :latest changes
  keel.sh/trigger: poll
  keel.sh/match-tag: "true"      # required for a moving tag like :latest
```

*Why `force` plus `match-tag`:* semver policies compare tags, and `latest` never
changes, so only digest matching detects a new build.

*No `pollSchedule`:* the cluster's Keel default applies. Pinning a per-workload
interval here would be one more number to keep in step with every other chart in
the homelab for no benefit — this app has no reason to poll faster or slower
than anything else.

*What this costs, stated plainly:* **git does not record what is running.**
`infra/` says `latest`, which is true forever and tells you nothing. Reverting a
commit in `infra/` rolls back configuration but not code, because no commit ever
named the image that is deployed. Recovery from a bad build is "push a good
image to `latest`" — roll forward, not back.

*Mitigation:* CI also pushes an immutable `sha-<commit>` tag alongside `latest`.
It is unused in the normal path, but during an incident, editing `image.tag` in
`infra/values.yaml` to `sha-<good>` and committing pins a known-good build and
takes Keel out of the loop until things are calm. Because `--set` does not exist
under Argo, that pin has to be a commit — which is the better outcome anyway:
the pinned version is recorded, and unpinning is a revert.

### CI/CD: GitHub Actions builds, Keel deploys

A GitHub Actions workflow on pushes to `main` builds the image and pushes
`ghcr.io/kvdomingo/resto-tracker` as both `latest` and `sha-<commit>`. That is
the whole delivery path — the workflow never talks to the cluster. Keel notices
the new digest and rolls the Deployment.

*Why no deploy step in CI:* it would need cluster credentials in GitHub, which
is a standing inbound path into the homelab in exchange for doing what Keel and
Argo already do from inside. Both pull; nothing outside needs push access.

*Two independent paths reach the cluster, and they do not overlap:* code changes
go `main` → image → Keel → pods, while deployment changes go `infra/` → git →
Argo → cluster. A pull request that touches only application code never
re-renders the chart, and one that touches only `infra/` never rebuilds an
image. That is why CI does not commit anything back to `infra/` — there is no
image tag to write there.

The workflow gates the push behind the same checks that run on pull requests —
tests, and the codegen freshness check that regenerates the sqlc output and
`schema.d.ts` and fails on any diff. An image only reaches `latest` if the
committed generated code matches its sources.

*Build-time input:* the Stytch public token is a build arg (see the one-image
decision), supplied from repository configuration. It is public, so it is a
variable rather than a secret; `GITHUB_TOKEN` covers authentication to GHCR.

### Scaling, disruption, and resources

| Setting | Value |
| --- | --- |
| HPA | `minReplicas: 2`, `maxReplicas: 5`, target 70% CPU utilisation |
| PDB | `minAvailable: 1` |
| App requests | `cpu: 100m`, `memory: 256Mi` |
| App limits | `cpu: 1000m`, `memory: 512Mi` |
| Migration initContainer | requests `cpu: 50m` / `memory: 64Mi`, limits `cpu: 500m` / `memory: 256Mi` |

*Why `minAvailable: 1` against an HPA floor of 2:* the PDB has to leave the
cluster room to evict. `minAvailable: 2` with a floor of 2 means no pod can ever
be drained, and a node upgrade blocks indefinitely on a budget that can never be
satisfied. At 1, a drain proceeds one pod at a time and the service stays up
throughout.

*Why a floor of 2 at all:* a single replica makes every node drain and every
rollout a brief outage. Two is the cheapest number that survives losing one.

*Why requests are far below limits:* the HPA measures CPU as a ratio against
*requests*, so a small request keeps that ratio meaningful for a mostly-idle
app, while the 1-core limit leaves burst room for a cold JWKS fetch or a large
list render without throttling before the HPA can react. The 70% target leaves
headroom for the ~30s scale-up lag.

*Why the memory limit is only 2× the request:* a FastAPI process with a
10-connection asyncpg pool sits around 150–200 MiB and stays flat — serving
static files costs page cache, not heap. A tight limit turns a leak into a
restarted pod rather than a node under memory pressure. Any OOMKill here is a
signal to investigate, not to raise the number.

**Connection budget.** The asyncpg pool is capped at 10 per pod, so the HPA
ceiling of 5 puts at most 50 connections on Postgres, plus one short-lived
connection per migration initContainer during a rollout. Small managed instances
cap out around 100, so this fits with room to spare — but raising `maxReplicas`
without shrinking the pool, or adding a connection pooler, is how that ceiling
gets breached.

**Nothing blocks running multiple replicas.** The only in-process state is the
cached JWKS, which each pod fetches independently; sessions live at Stytch and
everything else is in Postgres. Rollouts use `maxUnavailable: 0` so the PDB and
the rollout do not fight over the same pod.

## Risks / Trade-offs

- **Stytch is a hard dependency on a third party.** A Stytch outage means nobody
  can sign in, and their pricing governs the app's viability at scale. → Local
  JWT verification means an outage degrades to "existing sessions keep working
  for a few minutes, new sign-ins fail" rather than a total blackout. The auth
  surface is confined to one backend dependency module and the frontend's auth
  provider, so swapping providers is a bounded change.
- **`sqlc-gen-python` is an experimental plugin.** Generated-code bugs or an
  abandoned plugin would be painful. → Generated code is committed, so the repo
  keeps working even if the plugin breaks or disappears; worst case, the
  generated module is maintained by hand. Queries stay simple enough that
  hand-maintenance is feasible.
- **No ORM means hand-written SQL for every read.** More code and more room for
  a missed `owner_id` predicate — the highest-severity bug class in this app. →
  Every query lives in one `queries.sql` file so the ownership predicate can be
  audited by reading one file, and `specs/user-auth` ownership-isolation
  scenarios become tests that run against every endpoint.
- **Deleting and re-inserting locations on every edit** burns primary keys and
  writes rows that did not change. → Irrelevant at this scale; revisit if a
  location ever needs a stable external identifier.
- **Tags as `text[]`** cannot enforce a controlled vocabulary or carry per-tag
  metadata. → Accepted; free-form tags are what the spec asks for. Normalising
  into tables later is additive.
- **Baking the Stytch public token at build time** means one image per Stytch
  project, so test and production are different builds of the same commit. → It
  is the only baked value left now that the API base URL is relative, and it is
  public and stable; a runtime-config endpoint is the fallback if that stops
  being true.
- **One image couples frontend and backend releases.** A CSS typo means
  rebuilding and redeploying the API, and neither can scale independently of the
  other. → Both are cheap: the image builds in minutes and uvicorn pods are
  small. If the frontend ever needs a CDN or independent scaling, the bundle can
  be split back out without touching the API — the SPA mount is the only
  coupling point.
- **Dev runs two processes, production runs one image.** A bug in the served
  build — wrong asset base path, missing SPA fallback — will not show up under
  `docker compose up`. → `task build-local` runs the production image locally;
  task 11.2 exercises it before the change is called done.
- **Generated frontend types are only as good as the OpenAPI document.** A route
  returning a bare `dict` or a `response_model` left off produces a permissive
  type that compiles while lying. → Every route declares an explicit
  `response_model`; the contract test in 6.9 asserts real payloads against the
  declared schemas, so an undeclared response fails there rather than in the
  browser.
- **`latest` plus Keel means the cluster's running version is not recorded
  anywhere in git**, which is a real hole in an otherwise GitOps setup: Argo can
  tell you the manifests match, and still not tell you what code is running.
  Reverting a commit cannot undo a bad deploy. → CI also pushes an immutable
  `sha-<commit>` tag, so an incident can pin a known-good build by committing it
  to `values.yaml`; Keel's notifications are the record of what rolled when.
- **Argo CD self-heal and Keel both write to the Deployment.** If Argo reverts
  the field Keel mutates to force a rollout, new images either never land or
  land and get rolled back minutes later — intermittently, which is the worst
  way to find out. → A scoped `ignoreDifferences` on exactly that field,
  verified against the running Keel version in task 9.14 rather than guessed.
  Everything else stays under self-heal.
- **Migrations in an initContainer run during a rolling update**, so new and old
  code briefly share a schema. A destructive migration breaks the old pods
  before they drain. → Additive-only from here on; removals go through
  expand/contract across two releases. Task 2.5 verifies up/down, but nothing
  automatically enforces backward compatibility — it is a review discipline.
- **The Infisical operator is in the startup path.** If it is down or the
  identity's access is revoked, `<fullname>-secrets` never materialises and pods
  cannot start. → Existing pods keep running on their already-injected env, so
  this blocks deploys rather than causing an outage; the 10s resync means
  recovery is automatic once the operator is healthy.
- **Resource numbers are estimates, not measurements.** They come from what a
  FastAPI + asyncpg process typically uses, not from this app under load. → They
  are chart values, so correcting them is an edit to `values.yaml`. Task 11.5
  records actual usage under the local walkthrough as a first sanity check, and
  the HPA absorbs being wrong on the low side.

## Migration Plan

First deployment, so there is nothing to migrate from:

1. Provision Postgres and create the database.
2. Create Stytch test and live projects; put `DATABASE_URL`,
   `STYTCH_PROJECT_ID`, and `STYTCH_SECRET` in the `resto-tracker` Infisical
   project.
3. Push the first image so `ghcr.io/kvdomingo/resto-tracker:latest` exists —
   Argo's first sync will otherwise create pods that cannot pull.
4. Create the Argo CD Application pointing at `infra/` in this repository and
   sync it. The `InfisicalSecret` lands first in its sync-wave, the operator
   materialises `<fullname>-secrets`, then the app pods start and their
   initContainers run `dbmate up` against the empty database.
5. Confirm Keel has adopted the Deployment (annotations present, polling) and
   that its rollouts are not being reverted by Argo, before relying on automated
   deploys.

**Rollback is roll-forward.** Reverting a commit in `infra/` rolls back
configuration, but the deployed tag is `latest`, so it does not roll back code —
recovery from a bad build is pushing a good image, or committing
`image.tag: sha-<good>` for the duration of an incident. Schema rollback is
separate: `dbmate rollback` for the migrations in that release. Every migration
in this change is additive, so reverting the app without reverting the schema is
safe.

## Open Questions

- Whether Stytch's magic-link, OAuth, or both sign-in methods are enabled. This
  is a Stytch project setting and a choice of frontend SDK component; it changes
  no backend behaviour and no spec.
- Where the Argo CD `Application` manifest itself lives — in this repository
  alongside the chart, or with the rest of the homelab's Applications in an
  app-of-apps root. Either works; the chart in `infra/` is the same either way,
  so this can follow whatever convention the homelab already uses.
