#!/usr/bin/env bash
#
# scripts/deploy.sh — local manual deploy.
#
# Builds the site with `hugo --minify` (assumed already done by `make deploy`)
# and pushes the contents of public/ to the `gh-pages` branch on `origin`,
# using a temporary git worktree to avoid touching the current checkout.
#
set -euo pipefail

REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-gh-pages}"
WORKTREE_DIR=".deploy"

if [ ! -d public ]; then
  echo "error: public/ does not exist. Run 'make build' first." >&2
  exit 1
fi

# Ensure we have a local copy of the gh-pages branch.
if ! git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  if git ls-remote --exit-code --heads "${REMOTE}" "${BRANCH}" >/dev/null 2>&1; then
    git fetch "${REMOTE}" "${BRANCH}:${BRANCH}"
  else
    # Create an orphan branch from scratch.
    git worktree add --detach "${WORKTREE_DIR}" >/dev/null
    (
      cd "${WORKTREE_DIR}"
      git checkout --orphan "${BRANCH}"
      git rm -rf . >/dev/null 2>&1 || true
      git commit --allow-empty -m "Initial empty gh-pages"
    )
    git worktree remove --force "${WORKTREE_DIR}"
  fi
fi

# Add a worktree pointing at gh-pages.
trap 'git worktree remove --force "${WORKTREE_DIR}" >/dev/null 2>&1 || true' EXIT
git worktree add "${WORKTREE_DIR}" "${BRANCH}"

# Mirror public/ into the worktree, preserving its .git pointer.
rsync -a --delete --exclude '.git' public/ "${WORKTREE_DIR}/"

(
  cd "${WORKTREE_DIR}"
  git add -A
  if git diff --cached --quiet; then
    echo "No changes to deploy."
  else
    git commit -m "Deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    git push "${REMOTE}" "${BRANCH}"
  fi
)
