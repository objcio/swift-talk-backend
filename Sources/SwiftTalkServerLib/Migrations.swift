//
//  Migrations.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation
import Base


func runMigrations() throws {
    do {
        _ = try withConnection { conn in
            for m in migrations {
                do {
			_ = try conn.execute(m)
                } catch {
                    throw DatabaseError(err: error, query: m)
                }
            }
        }
    } catch {
        log(error)
    }
}

fileprivate let migrations: [String] = [
    """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
    """,
    """
    CREATE TABLE IF NOT EXISTS users (
        id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        email character varying NOT NULL,
        github_uid integer NOT NULL,
        github_login character varying NOT NULL,
        github_token character varying,
        avatar_url character varying,
        name character varying NOT NULL,
        remember_created_at timestamp NOT NULL,
        admin boolean DEFAULT false NOT NULL,
        created_at timestamp NOT NULL,
        updated_at timestamp NOT NULL,
        recurly_hosted_login_token character varying,
        payment_method_id uuid,
        last_reconciled_at timestamp,
        collaborator boolean DEFAULT false NOT NULL,
        download_credits integer DEFAULT 0 NOT NULL,
        subscriber boolean DEFAULT false NOT NULL
    );
    """,
    """
    CREATE INDEX IF NOT EXISTS users_github_uid ON users (github_uid);
    """,
    """
    CREATE TABLE IF NOT EXISTS sessions (
        id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        user_id uuid REFERENCES users NOT NULL,
        created_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
    );
    """,
    """
	ALTER TABLE users ADD COLUMN IF NOT EXISTS confirmed_name_and_email boolean DEFAULT false NOT NULL;
	""",
    """
	CREATE TABLE IF NOT EXISTS downloads (
		id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
		user_id uuid REFERENCES users NOT NULL,
		episode_id uuid NOT NULL,
		created_at timestamp NOT NULL,
		UNIQUE (user_id, episode_id)
	)
	""",
    """
    CREATE TABLE IF NOT EXISTS files (
        id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        key text NOT NULL,
        value text NOT NULL,
        UNIQUE (key)
    );
    """,
    """
    ALTER TABLE downloads
        DROP CONSTRAINT IF EXISTS downloads_user_id_episode_id_key,
        DROP COLUMN IF EXISTS episode_id,
        ADD COLUMN IF NOT EXISTS episode_number integer NOT NULL;
    """,
    """
    CREATE TABLE IF NOT EXISTS team_members (
        id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        user_id uuid REFERENCES users NOT NULL,
        team_member_id uuid REFERENCES users NOT NULL,
        UNIQUE (user_id, team_member_id)
    );
    """,
    """
    DROP INDEX IF EXISTS users_github_uid;
    """,
    """
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT * FROM pg_constraint WHERE conname='users_unique_github_uid') THEN
            ALTER TABLE users ADD CONSTRAINT users_unique_github_uid UNIQUE (github_uid);
        END IF;
        IF NOT EXISTS (SELECT * FROM pg_constraint WHERE conname='users_unique_github_login') THEN
            ALTER TABLE users ADD CONSTRAINT users_unique_github_login UNIQUE (github_login);
        END IF;
    END
    $$;
    """,
    // This one drops a bunch of duplicate constraints on the download table that have been created by a previous faulty migration
    """
    DO $body$
    DECLARE r record;
    BEGIN
        FOR r IN (select * from information_schema.constraint_table_usage where table_name='downloads' and constraint_name like 'downloads_episode_number_user_id_%')
        LOOP
            EXECUTE 'ALTER TABLE downloads DROP CONSTRAINT ' || quote_ident(r.constraint_name) || ';';
        END LOOP;
    END
    $body$;
    """,
    """
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT * FROM pg_constraint WHERE conname='downloads_unique_episode_number_user_id') THEN
            ALTER TABLE downloads ADD CONSTRAINT downloads_unique_episode_number_user_id UNIQUE (episode_number, user_id);
        END IF;
    END
    $$;
    """,
    """
    CREATE TABLE IF NOT EXISTS tasks (
        id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        date timestamp NOT NULL,
        json text NOT NULL
    );
    """,
    """
    CREATE INDEX IF NOT EXISTS tasks_date ON tasks (date);
    """,
    """
    ALTER TABLE tasks
        ADD COLUMN IF NOT EXISTS key text DEFAULT '' NOT NULL;
    """,
    """
    DELETE FROM tasks WHERE key = '';
    """,
    """
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT * FROM pg_constraint WHERE conname='tasks_unique_key') THEN
            ALTER TABLE tasks ADD CONSTRAINT tasks_unique_key UNIQUE (key);
        END IF;
    END
    $$;
    """,
    """
    ALTER TABLE users
        ADD COLUMN IF NOT EXISTS csrf uuid DEFAULT public.uuid_generate_v4() NOT NULL;
    """,
    """
    CREATE TABLE IF NOT EXISTS play_progress (
        id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        user_id uuid REFERENCES users NOT NULL,
        episode_number integer NOT NULL,
        progress integer DEFAULT 0 NOT NULL,
        UNIQUE (user_id, episode_number)
    );
    """,
    """
    ALTER TABLE users
    ADD COLUMN IF NOT EXISTS canceled BOOLEAN DEFAULT false NOT NULL;
    """,
    """
    ALTER TABLE play_progress
    ADD COLUMN IF NOT EXISTS furthest_watched integer DEFAULT 0 NOT NULL;
    """,
    """
    ALTER TABLE USERS
        ADD COLUMN IF NOT EXISTS download_credits_offset integer DEFAULT 0 NOT NULL;
    """,
    """
    CREATE TABLE IF NOT exists gifts (
    	id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        gifter_email text NOT NULL,
        gifter_name text NOT NULL,
        gifter_user_id uuid REFERENCES users,
        giftee_email text NOT NULL,
        giftee_name text NOT NULL,
        giftee_user_id uuid REFERENCES users,
        send_at timestamp NOT NULL,
        message text NOT NULL
    )
    """,
    """
    ALTER TABLE USERS
        ALTER github_login DROP NOT NULL,
        ALTER github_uid DROP NOT NULL
    """,
    """
    ALTER TABLE gifts
        ADD COLUMN IF NOT EXISTS subscription_id text;
    """,
    """
    ALTER TABLE gifts
        ADD COLUMN IF NOT EXISTS activated boolean DEFAULT FALSE NOT NULL;
    """,
    """
    ALTER TABLE gifts
        ALTER gifter_email DROP NOT NULL,
        ALTER gifter_name DROP NOT NULL
    """,
    """
    ALTER TABLE gifts
        ADD COLUMN IF NOT EXISTS plan_code text NOT NULL
    """,
    """
    ALTER TABLE users
        DROP COLUMN IF EXISTS remember_created_at,
        DROP COLUMN IF EXISTS payment_method_id,
        DROP COLUMN IF EXISTS last_reconciled_at,
        DROP COLUMN IF EXISTS updated_at
    """,
    """
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_name='users' AND column_name='role') THEN
            ALTER TABLE USERS
                ADD COLUMN IF NOT EXISTS role integer DEFAULT 0 NOT NULL;
            UPDATE USERS SET role = 1 WHERE collaborator;
            UPDATE USERS SET role = 2 WHERE admin;
            ALTER TABLE USERS
                DROP COLUMN IF EXISTS collaborator,
                DROP COLUMN IF EXISTS admin;
        END IF;
    END
    $$;
    """,
    """
    ALTER TABLE team_members
        ADD COLUMN IF NOT EXISTS created_at timestamp,
        ADD COLUMN IF NOT EXISTS expired_at timestamp,
        DROP CONSTRAINT IF EXISTS team_members_user_id_team_member_id_key
    """,
    """
    ALTER TABLE users
        DROP COLUMN IF EXISTS password,
        DROP COLUMN IF EXISTS password_reset,
        DROP COLUMN IF EXISTS username
    """,
    """
    ALTER TABLE team_members
        DROP CONSTRAINT IF EXISTS team_members_unique
    """,
    """
    DROP TABLE IF EXISTS signup_tokens
    """,
    """
    ALTER TABLE users
        ADD COLUMN IF NOT EXISTS team_token uuid DEFAULT public.uuid_generate_v4() NOT NULL
    """,
    """
    CREATE INDEX IF NOT EXISTS users_team_token_index ON users (team_token)
    """,
    // Populate the new created_at field on team_members where it is null.
    // We take the created_at date from the oldest team manager account the user is associated with.
    """
    UPDATE team_members SET created_at=dates.manager_created_at FROM (
        SELECT tm.team_member_id member_id, min(u.created_at) manager_created_at FROM
            users u INNER JOIN team_members tm ON u.id=tm.user_id
            GROUP BY tm.team_member_id
    ) AS dates WHERE team_members.team_member_id=dates.member_id AND created_at IS NULL
    """,
    // Now that created_at on team_members is populated for all old team members, we make it not null and set a default value.
    """
    ALTER TABLE team_members
        ALTER created_at SET DEFAULT LOCALTIMESTAMP,
        ALTER created_at SET NOT NULL
    """,
    """
    CREATE INDEX IF NOT EXISTS team_members_created_at_index ON team_members (created_at)
    """
]

