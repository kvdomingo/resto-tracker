\restrict dbmate

-- Dumped from database version 18.6 (Debian 18.6-1.pgdg12+2)
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
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


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
-- Name: restaurant_branch_list; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.restaurant_branch_list AS jsonb;


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
    created_by_id text,
    name text NOT NULL
);


--
-- Name: restaurant_branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurant_branches (
    id text DEFAULT public.idkit_ulid_generate() NOT NULL,
    restaurant_id text NOT NULL,
    geography public.geography(Point,4326) NOT NULL,
    label text NOT NULL
);


--
-- Name: restaurant_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurant_tags (
    restaurant_id text NOT NULL,
    tag_id text NOT NULL
);


--
-- Name: restaurant_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurant_visits (
    user_id text NOT NULL,
    restaurant_id text NOT NULL,
    has_visited boolean DEFAULT false NOT NULL
);


--
-- Name: restaurants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurants (
    id text DEFAULT public.idkit_ulid_generate() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_id text,
    name text NOT NULL,
    price_tier smallint NOT NULL,
    instagram_handle text,
    website text,
    menu_url text,
    is_reservation_required boolean DEFAULT false,
    CONSTRAINT restaurants_price_tier_check CHECK (((price_tier >= 1) AND (price_tier <= 5)))
);


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id text DEFAULT public.idkit_ulid_generate() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    author_id text,
    restaurant_id text NOT NULL,
    is_anonymous boolean DEFAULT false NOT NULL,
    content text NOT NULL,
    rating smallint NOT NULL,
    CONSTRAINT reviews_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id text DEFAULT public.idkit_ulid_generate() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by_id text,
    name public.citext NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id text DEFAULT public.idkit_ulid_generate() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    idp_user_id text NOT NULL,
    email public.citext NOT NULL,
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
-- Name: restaurant_branches restaurant_branches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant_branches
    ADD CONSTRAINT restaurant_branches_pkey PRIMARY KEY (id);


--
-- Name: restaurant_tags restaurant_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant_tags
    ADD CONSTRAINT restaurant_tags_pkey PRIMARY KEY (restaurant_id, tag_id);


--
-- Name: restaurants restaurants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT restaurants_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tags tags_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_name_key UNIQUE (name);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


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
-- Name: restaurant_branches__geography_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX restaurant_branches__geography_ix ON public.restaurant_branches USING gist (geography);


--
-- Name: restaurant_branches__restaurant_id_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX restaurant_branches__restaurant_id_ix ON public.restaurant_branches USING btree (restaurant_id);


--
-- Name: restaurant_tags__tag_id_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX restaurant_tags__tag_id_ix ON public.restaurant_tags USING btree (tag_id);


--
-- Name: restaurant_visits__restaurant_id_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX restaurant_visits__restaurant_id_ix ON public.restaurant_visits USING btree (restaurant_id);


--
-- Name: reviews__author_id_ix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reviews__author_id_ix ON public.reviews USING btree (author_id);


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
-- Name: groups groups_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: restaurant_branches restaurant_branches_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant_branches
    ADD CONSTRAINT restaurant_branches_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: restaurant_tags restaurant_tags_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant_tags
    ADD CONSTRAINT restaurant_tags_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: restaurant_tags restaurant_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant_tags
    ADD CONSTRAINT restaurant_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: restaurant_visits restaurant_visits_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant_visits
    ADD CONSTRAINT restaurant_visits_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id);


--
-- Name: restaurant_visits restaurant_visits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant_visits
    ADD CONSTRAINT restaurant_visits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: restaurants restaurants_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT restaurants_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: reviews reviews_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: reviews reviews_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: tags tags_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20260809064229'),
    ('20261011000000');
