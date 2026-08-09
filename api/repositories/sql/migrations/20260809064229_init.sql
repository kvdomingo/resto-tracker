-- migrate:up
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_idkit;
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE users (
  id          TEXT        NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at  TIMESTAMPTZ NOT NULL             DEFAULT NOW(),
  idp_user_id TEXT        NOT NULL UNIQUE,
  email       TEXT        NOT NULL UNIQUE,
  name        TEXT
);
CREATE INDEX users__idp_user_id_ix ON users (idp_user_id);
CREATE INDEX users__email_ix ON users (email);

CREATE TABLE groups (
  id         TEXT        NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at TIMESTAMPTZ NOT NULL             DEFAULT NOW(),
  name       TEXT        NOT NULL
);

CREATE TABLE group_memberships (
  user_id  TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  group_id TEXT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,

  CONSTRAINT group_memberships_pk PRIMARY KEY (user_id, group_id),
  CONSTRAINT group_memberships_uq UNIQUE (user_id, group_id)
);
CREATE INDEX group_memberships__group_id_ix ON group_memberships (group_id);

CREATE TYPE RESTAURANT_TIER AS ENUM (
  'FAST_FOOD',
  'PREMIUM_FAST_FOOD',
  'MID',
  'ENTRY_LEVEL_FINE_DINING',
  'HIGH_END_FINE_DINING'
  );

CREATE TABLE restaurants (
  id                      TEXT            NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at              TIMESTAMPTZ     NOT NULL             DEFAULT NOW(),
  created_by_id           TEXT            REFERENCES users (id) ON DELETE SET NULL,
  tier                    RESTAURANT_TIER NOT NULL,
  tags                    TEXT[]          NOT NULL             DEFAULT '{}'::TEXT[],
  location                GEOGRAPHY(Point),
  instagram_handle        TEXT,
  website                 TEXT,
  menu_url                TEXT,
  has_tried               BOOLEAN         NOT NULL             DEFAULT FALSE,
  is_reservation_required BOOLEAN                              DEFAULT FALSE
);
CREATE INDEX restaurants__tags_ix ON restaurants USING gin (tags);

-- migrate:down
DROP TABLE IF EXISTS restaurants;
DROP TABLE IF EXISTS group_memberships;
DROP TABLE IF EXISTS groups;
DROP TABLE IF EXISTS users;

DROP TYPE IF EXISTS RESTAURANT_TIER;

DROP EXTENSION IF EXISTS postgis;
DROP EXTENSION IF EXISTS pg_idkit;
DROP EXTENSION IF EXISTS pg_trgm;
