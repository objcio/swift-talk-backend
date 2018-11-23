//
//  Migrations.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation

func runMigrations() throws {
    DispatchQueue.global().async {
        do {
            _ = try withConnection { conn in
                for m in migrations { // global variable, but we could inject it at some point.
                    try conn.execute(m)
                }
            }
        } catch {
            log(error)
        }
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
]

