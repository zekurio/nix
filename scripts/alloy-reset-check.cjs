// Run as alloy: node scripts/alloy-reset-check.cjs /nix/store/...-alloy-0.0.1
// Only touches alloy_001_rehearsal, never the active database or media.
const assert = require('node:assert/strict');
const { mkdtempSync, cpSync, chmodSync, readFileSync, writeFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { createRequire } = require('node:module');
const { createHash } = require('node:crypto');
const pkg = process.argv[2];
const fromPackage = createRequire(join(pkg, 'share/alloy/server/package.json'));
const { Pool } = fromPackage('pg');
const { drizzle } = fromPackage('drizzle-orm/node-postgres');
const { migrate } = fromPackage('drizzle-orm/node-postgres/migrator');

async function main() {
  const pool = new Pool({ host: '/run/postgresql', user: 'alloy', database: 'alloy_001_rehearsal', max: 1 });
  const folder = mkdtempSync(join(tmpdir(), 'alloy-migration-check-'));
  try {
    const db = drizzle(pool);
    const migrationsFolder = join(pkg, 'share/alloy/migrations');
    const journal = () => pool.query('SELECT hash, created_at FROM drizzle.__drizzle_migrations ORDER BY id');
    const before = (await journal()).rows;
    assert.equal(before.length, 1);
    await migrate(db, { migrationsFolder });
    await migrate(db, { migrationsFolder });
    assert.deepEqual((await journal()).rows, before, 'baseline must not replay');

    cpSync(migrationsFolder, folder, { recursive: true });
    const metadata = join(folder, 'meta/_journal.json');
    chmodSync(metadata, 0o600);
    const entries = JSON.parse(readFileSync(metadata, 'utf8'));
    const when = entries.entries[0].when + 1;
    entries.entries.push({ idx: 1, version: '7', when, tag: '0001_upgrade_probe', breakpoints: true });
    writeFileSync(metadata, JSON.stringify(entries));
    const sql = 'CREATE TABLE public.alloy_upgrade_probe (id integer PRIMARY KEY);\nINSERT INTO public.alloy_upgrade_probe VALUES (1);\n';
    writeFileSync(join(folder, '0001_upgrade_probe.sql'), sql);
    await migrate(db, { migrationsFolder: folder });
    await migrate(db, { migrationsFolder: folder });
    assert.deepEqual((await pool.query('SELECT id FROM public.alloy_upgrade_probe')).rows, [{ id: 1 }]);
    assert.deepEqual((await journal()).rows, [...before, {
      hash: createHash('sha256').update(sql).digest('hex'), created_at: String(when),
    }]);
    console.log('PASS: packaged migrator skips the baseline, applies a future migration, and restarts idempotently');
  } finally {
    await pool.end();
    rmSync(folder, { recursive: true });
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
