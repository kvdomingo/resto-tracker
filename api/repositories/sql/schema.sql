\restrict dbmate

-- Dumped from database version 18.4 (Debian 18.4-1.pgdg12+1)
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_idkit; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_idkit WITH SCHEMA public;


--
-- Name: EXTENSION pg_idkit; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_idkit IS 'multi-tool for generating new/niche universally unique identifiers (ex. UUIDv6, ULID, KSUID)';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: restaurant_tier; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.restaurant_tier AS ENUM (
    'FAST_FOOD',
    'PREMIUM_FAST_FOOD',
    'MID',
    'ENTRY_LEVEL_FINE_DINING',
    'HIGH_END_FINE_DINING'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: group_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_memberships (
    user_id text NOT NULL,
    group_id text NOT NULL
);


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id text DEFAULT public.idkit_ulid_generate() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL
);


--
-- Name: restaurants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurants (
    id text DEFAULT public.idkit_ulid_generate() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_id text,
    tier public.restaurant_tier NOT NULL,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    location public.geography(Point,4326),
    instagram_handle text,
    website text,
    menu_url text,
    has_tried boolean DEFAULT false NOT NULL,
    is_reservation_required boolean DEFAULT false
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id text DEFAULT public.idkit_ulid_generate() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    idp_user_id text NOT NULL,
    email text NOT NULL,
    name text
);


--
-- Name: group_memberships group_memberships_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_pk PRIMARY KEY (user_id, group_id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: restaurants restaurants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT restaurants_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_idp_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_idp_user_id_key UNIQUE (idp_user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: group_memberships__group_id_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_memberships__group_id_ix ON public.group_memberships USING btree (group_id);


--
-- Name: restaurants__tags_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX restaurants__tags_ix ON public.restaurants USING gin (tags);


--
-- Name: users__email_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users__email_ix ON public.users USING btree (email);


--
-- Name: users__idp_user_id_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users__idp_user_id_ix ON public.users USING btree (idp_user_id);


--
-- Name: group_memberships group_memberships_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: group_memberships group_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_memberships
    ADD CONSTRAINT group_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: restaurants restaurants_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT restaurants_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20260809064229');
