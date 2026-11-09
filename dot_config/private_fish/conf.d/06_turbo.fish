# One turbo cache for every checkout and worktree. The default, <repo>/.turbo/cache,
# gives each linked worktree an empty cache, so lint and type-check re-run from
# scratch there. Task inputs hash file contents, so the same commit hits across
# checkouts. worktree-sweep prunes entries older than 14 days.
set -gx TURBO_CACHE_DIR $HOME/.cache/turbo
