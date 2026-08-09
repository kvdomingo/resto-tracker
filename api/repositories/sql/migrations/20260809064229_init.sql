-- migrate:up
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_idkit;
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE users (
  id TEXT NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  idp_user_id TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL UNIQUE,
  name TEXT
);
CREATE INDEX users__idp_user_id_ix ON users (idp_user_id);
CREATE INDEX users__email_ix ON users (email);

CREATE TABLE groups (
  id TEXT NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  name TEXT NOT NULL
);

CREATE TABLE group_memberships (
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  group_id TEXT NOT NULL REFERENCES groups (id) ON DELETE CASCADE,

  CONSTRAINT group_memberships_pk PRIMARY KEY (user_id, group_id),
  CONSTRAINT group_memberships_uq UNIQUE (user_id, group_id)
);
CREATE INDEX group_memberships__group_id_ix ON group_memberships (group_id);


CREATE TYPE RESTAURANT_BRANCH AS (
  location TEXT,
  geography GEOGRAPHY (POINT)
);

CREATE TABLE restaurants (
  id TEXT NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_id TEXT REFERENCES users (id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  price_tier SMALLINT NOT NULL CHECK (price_tier >= 1 AND price_tier <= 5),
  tags TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
  branches RESTAURANT_BRANCH[] NOT NULL CHECK (cardinality(branches) > 0),
  instagram_handle TEXT,
  website TEXT,
  menu_url TEXT,
  is_reservation_required BOOLEAN DEFAULT FALSE
);
CREATE INDEX restaurants__tags_ix ON restaurants USING gin (tags);

CREATE TABLE restaurant_visits (
  user_id TEXT NOT NULL REFERENCES users (id),
  restaurant_id TEXT NOT NULL REFERENCES restaurants (id),
  has_visited BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX restaurant_visits__restaurant_id_ix ON restaurant_visits (restaurant_id);

CREATE TABLE reviews (
  id TEXT NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  author_id TEXT REFERENCES users (id) ON DELETE SET NULL,
  restaurant_id TEXT NOT NULL REFERENCES restaurants (id) ON DELETE CASCADE,
  is_anonymous BOOLEAN NOT NULL DEFAULT FALSE,
  content TEXT NOT NULL,
  rating SMALLINT NOT NULL CHECK (rating >= 1 AND rating <= 5)
);
CREATE INDEX reviews__author_id_ix ON reviews (author_id);

-- migrate:down
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS restaurant_visits;
DROP TABLE IF EXISTS restaurants;
DROP TABLE IF EXISTS group_memberships;
DROP TABLE IF EXISTS groups;
DROP TABLE IF EXISTS users;

DROP TYPE IF EXISTS RESTAURANT_BRANCH;

DROP EXTENSION IF EXISTS postgis;
DROP EXTENSION IF EXISTS pg_idkit;
DROP EXTENSION IF EXISTS pg_trgm;
