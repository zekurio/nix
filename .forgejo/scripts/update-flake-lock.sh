#!/usr/bin/env bash
set -euo pipefail

branch=update-flake-lock
previous=$(git ls-remote origin "refs/heads/$branch" | cut -f1)
git checkout -B "$branch"
nix flake update --accept-flake-config
if git diff --quiet -- flake.lock; then
  echo "flake.lock is current."
  exit 0
fi

git config user.name 'forgejo-actions[bot]'
git config user.email 'forgejo-actions@noreply.git.zekurio.me'
git add flake.lock
git -c commit.gpgsign=false commit -m 'chore(flake): update flake.lock'
git push --force-with-lease="refs/heads/$branch:$previous" origin "HEAD:refs/heads/$branch"

node <<'JS'
const base = `${process.env.FORGEJO_SERVER_URL}/api/v1/repos/${process.env.FORGEJO_REPOSITORY}`;
const headers = {
  Authorization: `token ${process.env.FORGEJO_TOKEN}`,
  'Content-Type': 'application/json',
};
async function api(path, options = {}) {
  const response = await fetch(`${base}${path}`, { ...options, headers });
  if (!response.ok) throw new Error(`Forgejo API ${response.status}: ${path}`);
  return response.json();
}
async function main() {
  const branch = 'update-flake-lock';
  for (let page = 1; ; page++) {
    const pulls = await api(`/pulls?state=open&limit=50&page=${page}`);
    if (pulls.some(pr => pr.head.ref === branch && pr.base.ref === 'main'
        && pr.head.repo.full_name === process.env.FORGEJO_REPOSITORY)) {
      console.log('Updated the existing lock-file PR.');
      return;
    }
    if (pulls.length < 50) break;
  }
  const pr = await api('/pulls', {
    method: 'POST',
    body: JSON.stringify({
      head: branch,
      base: 'main',
      title: 'chore(flake): update flake.lock',
      body: 'Weekly flake input update. Review the lock-file changes and run `nix flake check` before merging.',
    }),
  });
  console.log(`Created ${pr.html_url}`);
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
JS
