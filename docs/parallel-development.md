# Working on several branches at once

Each change gets its own branch off `dev`, and a git worktree gives each branch
its own directory. `tool/worktree.sh` creates one that can actually build, and
removes it again when the branch has landed.

    tool/worktree.sh add keychain-read-failure
    tool/worktree.sh remove keychain-read-failure

Listing is `git worktree list`. The script adds nothing to it.

## What a new worktree costs

About five seconds, almost all of it dependency resolution. `git` gives you the
files; everything else a build needs is ignored and therefore not carried over.

| Step | Why it is not optional |
|------|------------------------|
| `flutter pub get` | Writes the root `.dart_tool` that `dart analyze` reads but never creates. Without it a fresh tree reports 7901 errors that are not there |
| `dart pub get` in `packages/app_backend` | That package sits outside the root package config and resolves on its own. `packages/engine` and `packages/mcp` do not |
| Copying `CLAUDE.local.md`, `.env`, `.claude`, `.vscode` | None are tracked. Without `CLAUDE.local.md` an agent in the new tree has no branch, commit or merge rules |

The branch is cut from `origin/dev` after a fetch, not from the local `dev` ref,
which goes stale the moment a pull request lands.

## Removing one

Removal refuses unless the branch is an ancestor of `origin/dev`, which is to
say it has been merged. It also refuses while the tree still holds work, and it
checks that before it touches anything: finding out afterwards would leave the
machine-local files in the Trash and the worktree still standing.

`git worktree remove` deletes with `rm` semantics. The copied `.env` holds live
credentials, so the local-only files go to the Trash first and git only gets to
delete what it tracks. That is why `trash` has to be installed; the script says
so rather than discovering it half way through.

An unmerged branch you want to abandon is not the script's business:

    git worktree remove ../FireRaccoon-<branch> && git branch -D <branch>

## What does not parallelise

`test/services/mcp_service_test.dart` binds loopback ports 18800 to 18809. Two
worktrees running the suite at the same moment fight over them, and the loser
fails for a reason that has nothing to do with either change. Run the suites one
at a time, or expect that failure and rerun.

The pre-commit hook is the whole CI gate: format, analyze, the engine, mcp and
app_backend suites, the full Flutter suite with coverage, then the coverage
buckets. It takes minutes and saturates the machine. Several agents committing
at once do not deadlock, they simply queue behind each other's CPU.

`dev` and `main` are refused as worktree branches. Both only ever move through
merges.

## When this is not worth it

One change at a time does not need a worktree; switching branches in the main
checkout is faster and keeps one `.dart_tool` warm. The cost of a worktree is
paid in disk and in the dependency resolution above, per tree, and again every
time dependencies change.
