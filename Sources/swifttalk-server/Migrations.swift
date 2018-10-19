//
//  Migrations.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation

func runMigrations() throws {
    try withConnection { conn in
        guard let c = conn else {
            print("Can't connect to database")
            return
        }
        tryOrLog {
            for m in migrations { // global variable, but we could inject it at some point.
                try c.execute(m)
            }
        }
    }
}

fileprivate let migrations: [String] = [
    //    """
    //    DROP TABLE IF EXusers IF EXISTS
    //    """,
    //    """
    //    DROP TABLE sessions
    //    """,
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
        ADD COLUMN IF NOT EXISTS episode_number integer NOT NULL,
        ADD UNIQUE (episode_number, user_id);
    """
]

