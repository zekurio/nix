-- Run as postgres against a newly restored copy of alloy_v1, never the source.
-- Pass -v baseline_file=/.../0000_bumpy_lethal_legion.sql to psql.
\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('alloy.baseline_file', :'baseline_file', true);
DO $guard$
BEGIN
  IF current_database() NOT IN ('alloy_001', 'alloy_001_rehearsal') THEN
    RAISE EXCEPTION 'Only the isolated 0.0.1 target may be migrated';
  END IF;
  IF encode(sha256(pg_read_binary_file(current_setting('alloy.baseline_file'))), 'hex')
      <> 'c41ec7134cfaa45adaab6baaa794778eb2149844e5810edb2b96048b6928154f' THEN
    RAISE EXCEPTION 'Unexpected baseline SQL';
  END IF;
  IF (SELECT md5(string_agg(hash || ':' || created_at, ',' ORDER BY created_at))
      FROM drizzle.__drizzle_migrations)
      IS DISTINCT FROM '4459d1ee96e8927a78e17ee380b842e1' THEN
    RAISE EXCEPTION 'Unexpected source migration history';
  END IF;
  IF (SELECT count(*) FROM information_schema.tables
      WHERE table_schema = 'public' AND table_type = 'BASE TABLE') <> 27 THEN
    RAISE EXCEPTION 'Expected all 27 source tables';
  END IF;
END
$guard$;

-- Renaming preserves every old row, column, index, and foreign key. The app
-- cannot access the archive, and its normal public schema matches upstream.
ALTER SCHEMA public RENAME TO alloy_legacy;
ALTER SCHEMA alloy_legacy OWNER TO postgres;
REVOKE ALL ON SCHEMA alloy_legacy FROM PUBLIC, alloy;
ALTER SCHEMA drizzle RENAME TO alloy_legacy_drizzle;
ALTER SCHEMA alloy_legacy_drizzle OWNER TO postgres;
REVOKE ALL ON SCHEMA alloy_legacy_drizzle FROM PUBLIC, alloy;
CREATE SCHEMA public AUTHORIZATION alloy;
SET LOCAL ROLE alloy;
\i :baseline_file
CREATE SCHEMA drizzle AUTHORIZATION alloy;
CREATE TABLE drizzle.__drizzle_migrations (
  id serial PRIMARY KEY,
  hash text NOT NULL,
  created_at bigint
);
INSERT INTO drizzle.__drizzle_migrations (hash, created_at)
VALUES ('c41ec7134cfaa45adaab6baaa794778eb2149844e5810edb2b96048b6928154f', 1789247789003);
RESET ROLE;

DO $import$
DECLARE
  tbl text;
  cols text;
  differs boolean;
  copied bigint;
BEGIN
  -- Parent tables first, with every FK, CHECK, and uniqueness constraint on.
  FOREACH tbl IN ARRAY ARRAY[
    'user', 'game', 'auth_account', 'auth_challenge', 'auth_session',
    'auth_refresh_token', 'user_passkey', 'clip', 'clip_mention',
    'clip_rendition', 'clip_tag', 'clip_view', 'game_detection_mapping',
    'instance_setting', 'upload_ticket', 'block', 'storage_deletion',
    'webhook', 'webhook_delivery'
  ] LOOP
    SELECT string_agg(format('%I', column_name), ', ' ORDER BY ordinal_position)
    INTO STRICT cols FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = tbl;
    IF cols IS NULL THEN
      RAISE EXCEPTION 'Missing target table %', tbl;
    END IF;
    -- Missing source columns fail; nothing is silently defaulted or changed.
    EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM alloy_legacy.%I',
                   tbl, cols, cols, tbl);
    GET DIAGNOSTICS copied = ROW_COUNT;
    EXECUTE format(
      'SELECT EXISTS ((SELECT %s FROM public.%I EXCEPT ALL SELECT %s FROM alloy_legacy.%I)
                UNION ALL (SELECT %s FROM alloy_legacy.%I EXCEPT ALL SELECT %s FROM public.%I))',
      cols, tbl, cols, tbl, cols, tbl, cols, tbl) INTO differs;
    IF differs THEN
      RAISE EXCEPTION 'Data mismatch in %', tbl;
    END IF;
    RAISE NOTICE 'Verified %: % rows, every supported column', tbl, copied;
  END LOOP;
  IF (SELECT count(*) FROM information_schema.tables
      WHERE table_schema = 'public' AND table_type = 'BASE TABLE') <> 19 THEN
    RAISE EXCEPTION 'Unexpected target tables';
  END IF;
END
$import$;

CREATE TABLE alloy_migration.reset_001 (
  complete boolean PRIMARY KEY CHECK (complete),
  completed_at timestamptz NOT NULL DEFAULT now(),
  source_database text NOT NULL DEFAULT 'alloy_v1'
);
INSERT INTO alloy_migration.reset_001 (complete) VALUES (true);
COMMIT;
