--
-- PostgreSQL database dump
--

-- Dumped from database version 10.4
-- Dumped by pg_dump version 10.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET default_tablespace = '';
SET default_with_oids = false;

CREATE TABLE public.auth_tokens (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    token character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

CREATE TABLE public.credit_cards (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    first_name character varying,
    last_name character varying,
    company character varying,
    address1 character varying,
    address2 character varying,
    city character varying,
    state character varying,
    zip character varying,
    country character varying,
    phone character varying,
    vat_number character varying,
    ip_address character varying,
    ip_address_country character varying,
    card_type character varying,
    year integer,
    month integer,
    first_six character varying,
    last_four character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


CREATE TABLE public.downloads (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    episode_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


CREATE TABLE public.episode_resources (
    id integer NOT NULL,
    episode_id uuid,
    title character varying,
    subtitle character varying,
    url character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


CREATE TABLE public.episode_views (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    episode_id uuid,
    user_id uuid,
    play_count integer DEFAULT 0 NOT NULL,
    last_played_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    furthest_watched integer,
    play_position integer
);


CREATE TABLE public.invoices (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    recurly_id character varying,
    recurly_subscription_id character varying,
    state integer,
    total integer,
    net_terms integer,
    invoice_number_prefix character varying,
    invoice_number integer,
    invoiced_at timestamp without time zone,
    closed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    tax integer
);


CREATE TABLE public.payment_methods (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    type character varying,
    user_id uuid,
    first_name character varying,
    last_name character varying,
    company character varying,
    address1 character varying,
    address2 character varying,
    city character varying,
    state character varying,
    zip character varying,
    country character varying,
    phone character varying,
    vat_number character varying,
    ip_address character varying,
    ip_address_country character varying,
    card_type character varying,
    year integer,
    month integer,
    first_six character varying,
    last_four character varying,
    paypal_billing_agreement_id character varying,
    amazon_billing_agreement_id character varying,
    name_on_account character varying,
    routing_number character varying,
    account_number character varying,
    account_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


CREATE TABLE public.payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    payment_method_id uuid,
    payment_method_type character varying,
    recurly_id character varying,
    recurly_invoice_id character varying,
    recurly_subscription_id character varying,
    state integer,
    action integer,
    amount integer,
    message character varying,
    reference character varying,
    test boolean,
    voidable boolean,
    refundable boolean,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    charged_at timestamp without time zone
);


CREATE TABLE public.subscription_add_ons (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    subscription_id uuid,
    add_on_id character varying,
    quantity integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


CREATE TABLE public.subscriptions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    plan_id character varying,
    recurly_id character varying,
    state integer,
    activated_at timestamp without time zone,
    canceled_at timestamp without time zone,
    expires_at timestamp without time zone,
    current_period_started_at timestamp without time zone,
    current_period_ends_at timestamp without time zone,
    trial_started_at timestamp without time zone,
    trial_ends_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    unit_amount integer,
    team_members integer DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    tax integer DEFAULT 0 NOT NULL,
    tax_rate double precision,
    tax_region character varying,
    team_member_amount integer
);

CREATE TABLE public.team_member_associations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    owner_id uuid,
    user_id uuid,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


CREATE TABLE public.user_devices (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    name character varying,
    guid character varying,
    apn_token character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    email character varying,
    github_uid integer,
    github_login character varying,
    github_token character varying,
    avatar_url character varying,
    name character varying,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip inet,
    last_sign_in_ip inet,
    admin boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    recurly_hosted_login_token character varying,
    payment_method_id uuid,
    last_reconciled_at timestamp without time zone,
    receive_new_episode_emails boolean DEFAULT true,
    collaborator boolean,
    download_credits integer DEFAULT 0 NOT NULL
);

--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: auth_tokens auth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.auth_tokens
    ADD CONSTRAINT auth_tokens_pkey PRIMARY KEY (id);


--
-- Name: collaborators collaborators_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.collaborators
    ADD CONSTRAINT collaborators_pkey PRIMARY KEY (id);


--
-- Name: collection_episodes collection_episodes_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.collection_episodes
    ADD CONSTRAINT collection_episodes_pkey PRIMARY KEY (id);


--
-- Name: collections collections_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.collections
    ADD CONSTRAINT collections_pkey PRIMARY KEY (id);


--
-- Name: credit_cards credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.credit_cards
    ADD CONSTRAINT credit_cards_pkey PRIMARY KEY (id);


--
-- Name: downloads downloads_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.downloads
    ADD CONSTRAINT downloads_pkey PRIMARY KEY (id);


--
-- Name: episode_resources episode_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.episode_resources
    ADD CONSTRAINT episode_resources_pkey PRIMARY KEY (id);


--
-- Name: episode_updates episode_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.episode_updates
    ADD CONSTRAINT episode_updates_pkey PRIMARY KEY (id);


--
-- Name: episode_views episode_views_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.episode_views
    ADD CONSTRAINT episode_views_pkey PRIMARY KEY (id);


--
-- Name: episodes episodes_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.episodes
    ADD CONSTRAINT episodes_pkey PRIMARY KEY (id);


--
-- Name: friendly_id_slugs friendly_id_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.friendly_id_slugs
    ADD CONSTRAINT friendly_id_slugs_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: payment_methods payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.payment_methods
    ADD CONSTRAINT payment_methods_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: seasons seasons_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.seasons
    ADD CONSTRAINT seasons_pkey PRIMARY KEY (id);


--
-- Name: subscription_add_ons subscription_add_ons_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.subscription_add_ons
    ADD CONSTRAINT subscription_add_ons_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: team_member_associations team_member_associations_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.team_member_associations
    ADD CONSTRAINT team_member_associations_pkey PRIMARY KEY (id);


--
-- Name: temp_auth_tokens temp_auth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.temp_auth_tokens
    ADD CONSTRAINT temp_auth_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_devices user_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.user_devices
    ADD CONSTRAINT user_devices_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_collaborators_episodes_on_collaborator_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_collaborators_episodes_on_collaborator_id ON public.collaborators_episodes USING btree (collaborator_id);


--
-- Name: index_collaborators_episodes_on_episode_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_collaborators_episodes_on_episode_id ON public.collaborators_episodes USING btree (episode_id);


--
-- Name: index_collection_episodes_on_collection_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_collection_episodes_on_collection_id ON public.collection_episodes USING btree (collection_id);


--
-- Name: index_collection_episodes_on_episode_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_collection_episodes_on_episode_id ON public.collection_episodes USING btree (episode_id);


--
-- Name: index_collections_on_slug; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_collections_on_slug ON public.collections USING btree (slug);


--
-- Name: index_downloads_on_episode_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_downloads_on_episode_id ON public.downloads USING btree (episode_id);


--
-- Name: index_downloads_on_user_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_downloads_on_user_id ON public.downloads USING btree (user_id);


--
-- Name: index_episode_resources_on_episode_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_episode_resources_on_episode_id ON public.episode_resources USING btree (episode_id);


--
-- Name: index_episode_updates_on_episode_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_episode_updates_on_episode_id ON public.episode_updates USING btree (episode_id);


--
-- Name: index_episode_views_on_episode_id_and_user_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_episode_views_on_episode_id_and_user_id ON public.episode_views USING btree (episode_id, user_id);


--
-- Name: index_episodes_on_name; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_episodes_on_name ON public.episodes USING btree (name);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type ON public.friendly_id_slugs USING btree (slug, sluggable_type);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope ON public.friendly_id_slugs USING btree (slug, sluggable_type, scope);


--
-- Name: index_friendly_id_slugs_on_sluggable_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_id ON public.friendly_id_slugs USING btree (sluggable_id);


--
-- Name: index_friendly_id_slugs_on_sluggable_type; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_type ON public.friendly_id_slugs USING btree (sluggable_type);


--
-- Name: index_invoices_on_recurly_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_invoices_on_recurly_id ON public.invoices USING btree (recurly_id);


--
-- Name: index_invoices_on_recurly_subscription_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_invoices_on_recurly_subscription_id ON public.invoices USING btree (recurly_subscription_id);


--
-- Name: index_invoices_on_user_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_invoices_on_user_id ON public.invoices USING btree (user_id);


--
-- Name: index_payment_methods_on_type; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_payment_methods_on_type ON public.payment_methods USING btree (type);


--
-- Name: index_payment_methods_on_user_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_payment_methods_on_user_id ON public.payment_methods USING btree (user_id);


--
-- Name: index_payments_on_action; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_payments_on_action ON public.payments USING btree (action);


--
-- Name: index_payments_on_payment_method; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_payments_on_payment_method ON public.payments USING btree (payment_method_id, payment_method_type);


--
-- Name: index_payments_on_recurly_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_payments_on_recurly_id ON public.payments USING btree (recurly_id);


--
-- Name: index_payments_on_recurly_invoice_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_payments_on_recurly_invoice_id ON public.payments USING btree (recurly_invoice_id);


--
-- Name: index_payments_on_recurly_subscription_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_payments_on_recurly_subscription_id ON public.payments USING btree (recurly_subscription_id);


--
-- Name: index_payments_on_state; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_payments_on_state ON public.payments USING btree (state);


--
-- Name: index_payments_on_user_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_payments_on_user_id ON public.payments USING btree (user_id);


--
-- Name: index_seasons_on_number; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_seasons_on_number ON public.seasons USING btree (number);


--
-- Name: index_subscriptions_on_recurly_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_subscriptions_on_recurly_id ON public.subscriptions USING btree (recurly_id);


--
-- Name: index_subscriptions_on_state; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_subscriptions_on_state ON public.subscriptions USING btree (state);


--
-- Name: index_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_subscriptions_on_user_id ON public.subscriptions USING btree (user_id);


--
-- Name: index_temp_auth_tokens_on_code; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_temp_auth_tokens_on_code ON public.temp_auth_tokens USING btree (code);


--
-- Name: index_user_devices_on_user_id_and_guid; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_user_devices_on_user_id_and_guid ON public.user_devices USING btree (user_id, guid);


--
-- Name: index_users_on_github_uid; Type: INDEX; Schema: public; Owner: chris
--

CREATE UNIQUE INDEX index_users_on_github_uid ON public.users USING btree (github_uid);


--
-- Name: index_users_on_receive_new_episode_emails; Type: INDEX; Schema: public; Owner: chris
--

CREATE INDEX index_users_on_receive_new_episode_emails ON public.users USING btree (receive_new_episode_emails);


--
-- Name: collaborators_episodes fk_rails_9d318a43c5; Type: FK CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.collaborators_episodes
    ADD CONSTRAINT fk_rails_9d318a43c5 FOREIGN KEY (episode_id) REFERENCES public.episodes(id);


--
-- Name: episode_updates fk_rails_b60c721704; Type: FK CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.episode_updates
    ADD CONSTRAINT fk_rails_b60c721704 FOREIGN KEY (episode_id) REFERENCES public.episodes(id);


--
-- Name: collaborators_episodes fk_rails_f381706465; Type: FK CONSTRAINT; Schema: public; Owner: chris
--

ALTER TABLE ONLY public.collaborators_episodes
    ADD CONSTRAINT fk_rails_f381706465 FOREIGN KEY (collaborator_id) REFERENCES public.collaborators(id);


--
-- PostgreSQL database dump complete
--


