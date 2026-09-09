#!/usr/bin/env bash
#
# One worktree per branch, branched off dev.
# Usage: tool/worktree.sh add <branch> | remove <branch>
#
# Listing is git worktree list; there is nothing this would add to it.

set -euo pipefail

CURRENT_ROOT="$(git rev-parse --show-toplevel)"
cd "$CURRENT_ROOT"

# Resolved through the shared git dir so every subcommand behaves the same
# whether it runs from the main checkout or from a worktree it created.
MAIN_ROOT="$(dirname "$(cd "$(git rev-parse --git-common-dir)" && pwd)")"

# Ignored files, so a fresh worktree starts without them. CLAUDE.local.md is the
# one that matters: without it an agent working in the new tree has no branch,
# commit or merge rules.
LOCAL_ONLY=(CLAUDE.local.md .env .claude .vscode)

section() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$1"
}

fail() {
  printf '\n\033[1;31m✗ worktree: %s\033[0m\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  tool/worktree.sh add <branch>     Create a sibling worktree on a new branch off dev
  tool/worktree.sh remove <branch>  Delete a merged branch's worktree and the branch
EOF
}

# dev only moves through merges on the remote, so the local ref is stale from
# the moment someone lands a pull request.
base_ref() {
  git fetch --quiet origin dev 2>/dev/null \
    || printf 'could not reach origin, using the local refs\n' >&2
  if git show-ref --verify --quiet refs/remotes/origin/dev; then
    echo origin/dev
  else
    echo dev
  fi
}

worktree_for() {
  git worktree list --porcelain | awk -v ref="branch refs/heads/$1" '
    /^worktree / { path = substr($0, 10) }
    $0 == ref { print path; exit }
  '
}

cmd_add() {
  local branch="${1-}"
  [[ -n "$branch" ]] || fail "usage: tool/worktree.sh add <branch>"

  # Work never happens on either line: dev takes merges only, main takes dev.
  case "$branch" in
    dev | main) fail "$branch takes merges only; give the change its own branch" ;;
  esac

  [[ "$branch" =~ ^[a-z0-9][a-z0-9.-]*$ ]] \
    || fail "branch names are lowercase and unprefixed, like keychain-read-failure"

  local dir="$MAIN_ROOT-$branch"
  local base
  base="$(base_ref)"

  section "Adding $dir on $branch off $base"
  # --no-track leaves the branch with no upstream, so the first push has to name
  # one rather than inheriting origin/dev.
  git worktree add --no-track -b "$branch" "$dir" "$base"

  section "Copying local-only files"
  local name
  for name in "${LOCAL_ONLY[@]}"; do
    if [[ -e "$MAIN_ROOT/$name" ]]; then
      cp -R "$MAIN_ROOT/$name" "$dir/$name"
      echo "  $name"
    fi
  done
  ( cd "$dir" && bash tool/setup-ci-env.sh )

  section "Resolving dependencies"
  # flutter pub get writes the root .dart_tool that dart analyze reads but never
  # creates, so skipping it makes the pre-commit hook report thousands of
  # phantom errors. app_backend sits outside the root package config and has to
  # resolve on its own.
  ( cd "$dir" && flutter pub get )
  ( cd "$dir/packages/app_backend" && dart pub get )

  printf '\n\033[1;32m✓ %s ready\033[0m\n' "$dir"
  echo "  cd $dir"
  # The one place two of these genuinely collide. Everything else is per-tree.
  echo "  note: test/services/mcp_service_test.dart binds 18800-18809, so do"
  echo "        not run the suite in two worktrees at the same moment"
}

cmd_remove() {
  local branch="${1-}"
  [[ -n "$branch" ]] || fail "usage: tool/worktree.sh remove <branch>"
  command -v trash >/dev/null \
    || fail "trash is not installed; brew install trash. Removal puts the
    machine-local files in this worktree in the Trash before git deletes it"

  local dir
  dir="$(worktree_for "$branch")"
  [[ -n "$dir" ]] || fail "no worktree holds $branch"
  [[ "$dir" != "$CURRENT_ROOT" ]] || fail "run this from another worktree; $dir is the one you are in"
  [[ "$dir" != "$MAIN_ROOT" ]] || fail "$branch is checked out in the main checkout; switch that one to dev instead"

  local base
  base="$(base_ref)"
  git merge-base --is-ancestor "refs/heads/$branch" "$base" || fail \
    "$branch is not merged into $base; once it lands, or to drop it unmerged: git worktree remove $dir && git branch -D $branch"

  # Checked before anything is trashed. git refuses to remove a worktree that
  # holds work, and finding that out afterwards leaves the machine-local files
  # in the Trash and the worktree still standing.
  local dirt
  dirt="$(git -C "$dir" status --porcelain | grep -vE "^.. ($(IFS='|'; echo "${LOCAL_ONLY[*]}"))/?$" || true)"
  [[ -z "$dirt" ]] || fail "$dir still holds work:
$dirt"

  # git worktree remove deletes with rm semantics: the copied .env, with live
  # credentials in it, and CLAUDE.local.md would be gone with no way back. The
  # repo's rule is trash, never rm, so anything git will not miss goes to the
  # Trash first and the removal only takes what git itself tracks.
  section "Trashing the local-only files in $dir"
  local name
  for name in "${LOCAL_ONLY[@]}"; do
    if [[ -e "$dir/$name" ]]; then
      trash "$dir/$name"
      echo "  $name"
    fi
  done

  section "Removing $dir"
  git worktree remove "$dir"
  # -D rather than -d: the ancestor check above already proved the branch is in
  # $base, which -d cannot see from a worktree sitting on something else.
  git branch -D "$branch"

  printf '\n\033[1;32m✓ %s removed\033[0m\n' "$branch"
}

cmd="${1-}"
shift || true
case "$cmd" in
  add) cmd_add "$@" ;;
  remove) cmd_remove "$@" ;;
  *)
    usage >&2
    exit 1
    ;;
esac
