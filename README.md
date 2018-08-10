# video-swift-backend

A description of this package.

# Exporting static data from the old database

- Episodes. In psql, do the following:

```
\t on
\pset format unaligned
SELECT json_agg(t) FROM (SELECT e.id, number, title, release_at, created_at, updated_at, season, media_duration, media_src, subscription_only, name, synopsis, media_version, released, poster_uid, sample_src, sample_duration, sample_version, video_id, mailchimp_campaign_id, (SELECT array(SELECT collection_id FROM collection_episodes where episode_id = e.id ORDER BY "primary" ASC) as collections) FROM episodes e) t \g episodes.json
```

# Postgres

```
initdb -D .postgres
chmod 700 .postgres
pg_ctl -D .postgres start
```

