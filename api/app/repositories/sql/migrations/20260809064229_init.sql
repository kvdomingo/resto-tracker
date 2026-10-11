-- migrate:up
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_idkit;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id TEXT NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  idp_user_id TEXT NOT NULL UNIQUE,
  email CITEXT NOT NULL UNIQUE,
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

CREATE TABLE restaurants (
  id TEXT NOT NULL PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_id TEXT REFERENCES users (id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  price_tier SMALLINT NOT NULL CHECK (price_tier >= 1 AND price_tier <= 5),
  instagram_handle TEXT,
  website TEXT,
  menu_url TEXT,
  is_reservation_required BOOLEAN DEFAULT FALSE
);

CREATE TABLE tags (
  id TEXT PRIMARY KEY DEFAULT idkit_ulid_generate(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by_id TEXT REFERENCES users (id) ON DELETE SET NULL,
  name CITEXT UNIQUE NOT NULL
);

CREATE TABLE restaurant_tags (
  restaurant_id TEXT NOT NULL REFERENCES restaurants (id) ON DELETE CASCADE,
  tag_id TEXT NOT NULL REFERENCES tags (id) ON DELETE CASCADE,

  PRIMARY KEY (restaurant_id, tag_id)
);
CREATE INDEX restaurant_tags__tag_id_ix ON restaurant_tags (tag_id);

CREATE TABLE restaurant_branches (
  id TEXT PRIMARY KEY DEFAULT idkit_ulid_generate(),
  restaurant_id TEXT NOT NULL REFERENCES restaurants (id) ON DELETE CASCADE,
  geography GEOGRAPHY (POINT) NOT NULL,
  label TEXT NOT NULL
);
CREATE INDEX restaurant_branches__restaurant_id_ix
ON restaurant_branches (restaurant_id);
CREATE INDEX restaurant_branches__geography_ix
ON restaurant_branches USING gist (geography);

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
DROP TABLE IF EXISTS restaurant_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS restaurant_branches;
DROP TABLE IF EXISTS restaurants;
DROP TABLE IF EXISTS group_memberships;
DROP TABLE IF EXISTS groups;
DROP TABLE IF EXISTS users;

DROP EXTENSION IF EXISTS citext;
DROP EXTENSION IF EXISTS postgis;
DROP EXTENSION IF EXISTS pg_idkit;
DROP EXTENSION IF EXISTS pg_trgm;
