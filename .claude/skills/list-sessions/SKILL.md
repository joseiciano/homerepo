---
name: list-sessions
description: List active workmux sessions that the homerepo delegated. Use for /list-sessions.
disable-model-invocation: true
---

# list-sessions

Homerepo delegations run in the tmux session named `homerepo` (set with `--parent-session homerepo` at spawn time, see `AGENTS.md`). That session name is the marker for work delegated from here.

## Steps

1. Run `workmux status --json`.
2. Keep agents whose `session` equals `homerepo`. Each listed agent is active, so keep all statuses: working, waiting, done.
3. For each kept agent, print one line: `<worktree>  <status>  <elapsed>  <workdir>`. Convert `elapsed_secs` to minutes or hours.
4. Mark `waiting` agents as needing input.
5. When no agent matches, print `No active homerepo sessions.`

Done when every agent with `session == homerepo` is printed or the empty message is shown.
