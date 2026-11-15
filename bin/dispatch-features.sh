#!/bin/bash
# Feature dispatcher: polls features/ready/ and delegates each feature file to
# a claude worktree agent in the target project.
#
# File format (features/ready/<anything>.md):
#   Project: <Project in workspace>
#
#   Feature:
#   <Description of the feature we want>
#
# The project name must be a line in projects.md (`name: /path/to/repo`).
# Drafts go in features/draft/ — never picked up. Dispatched files move to
# features/.dispatched/, failures to features/failed/.
# The concurrency cap lives in bin/dispatch.conf (max_in_flight).
set -u

HOMEREPO="$(cd "$(dirname "$0")/.." && pwd)"
FEATURES_DIR="$HOMEREPO/features"
READY_DIR="$FEATURES_DIR/ready"
CONSUMED_DIR="$FEATURES_DIR/.dispatched"
FAILED_DIR="$FEATURES_DIR/failed"
PROJECTS="$HOMEREPO/projects.md"
CONF="$HOMEREPO/bin/dispatch.conf"
LOG="$HOMEREPO/features/.dispatch.log"

# cron PATH is minimal; workmux lives in /opt/homebrew/bin.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

mkdir -p "$READY_DIR" "$CONSUMED_DIR" "$FAILED_DIR"

# One dispatcher run at a time; a leftover lock from a killed run is removed
# when the lock directory has no live owner process.
LOCK="$HOMEREPO/features/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  owner_pid="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [ -n "$owner_pid" ] && ! kill -0 "$owner_pid" 2>/dev/null; then
    rm -rf "$LOCK"
    mkdir "$LOCK" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "$LOG"; }

# Tunables
max_in_flight=5
branch_prefix=feature
agent=claude
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1090
  . "$CONF"
fi

# Count delegated sessions that are still open: any agent whose tmux session
# is `homerepo` (the --parent-session marker). Done agents vanish from the
# list only after their window closes, so done-but-open windows still count
# toward the cap. That is conservative and fine.
in_flight() {
  workmux status --json 2>/dev/null \
    | jq '[.agents[] | select(.session == "homerepo")] | length'
}

# Everything runs inside the tmux `homerepo` session so `workmux add` places
# windows there; running headless from cron still works because we always
# pass --parent-session.
export TMUX_SESSION_NAME=homerepo

shipped=0
for file in "$READY_DIR"/*.md; do
  [ -e "$file" ] || exit 0   # no files

  name="$(basename "$file")"

  # Parse format: "Project: X" ... "Feature:" ... description
  project="$(sed -n 's/^Project:[[:space:]]*//p' "$file" | head -1 | tr -d '[:space:]' )"
  desc="$(awk '/^Feature:/{found=1; next} found{print}' "$file" | sed '/^[[:space:]]*$/d')"
  if [ -z "$project" ] || [ -z "$desc" ]; then
    log "FAIL $name: missing 'Project:' line or 'Feature:' body"
    mv "$file" "$FAILED_DIR/$name"
    continue
  fi

  # Resolve project path from projects.md
  path="$(grep -E "^${project}:[[:space:]]*" "$PROJECTS" | head -1 | sed "s/^${project}:[[:space:]]*//")"
  if [ -z "$path" ] || [ ! -d "$path" ]; then
    log "FAIL $name: project '$project' not in projects.md or path missing"
    mv "$file" "$FAILED_DIR/$name"
    continue
  fi

  # Cap check: counted before each dispatch so one run cannot overshoot.
  n="$(in_flight)"
  if [ "${n:-0}" -ge "$max_in_flight" ]; then
    log "SKIP $name: cap reached ($n/$max_in_flight)"
    exit 0
  fi

  branch="${branch_prefix}-$(echo "$name" | sed -E 's/\.md$//; s/[^a-zA-Z0-9._/-]+/-/g; s/^-+|-+$//g' | cut -c1-40)"
  branch="${branch%/}"   # workmux treats trailing slash specially

  log "DISPATCH $name -> $project ($branch)"
  if (cd "$path" && workmux add "$branch" -a "$agent" -b --parent-session homerepo -P "$file"); then
    mv "$file" "$CONSUMED_DIR/$name"
    shipped=$((shipped + 1))
    log "OK $name shipped ($shipped this run)"
  else
    log "FAIL $name: workmux add failed for $project"
    mv "$file" "$FAILED_DIR/$name"
  fi
done

[ "$shipped" -gt 0 ] && log "run complete: $shipped shipped"
exit 0
