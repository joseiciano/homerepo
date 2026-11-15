# features/

Drop a feature request here; the dispatcher picks it up on its next cron run
(every 10 minutes) and delegates it to a claude worktree agent.

## Folders

- `features/ready/` — the dispatcher scans only this folder.
- `features/draft/` — work in progress; never picked up. Move a file into
  `ready/` when you want it dispatched.
- `features/failed/` — bad format, unknown project, or workmux failure.
  Fix and move the file back into `ready/` to retry.
- `features/.dispatched/` — handed to an agent successfully.

## File format

Any `*.md` file named however you like, e.g. `ready/mako-dark-mode.md`:

```
Project: mako

Feature:
Add a dark mode toggle to the settings page. It should persist the
preference and respect the system setting by default.
```

- `Project:` must match a name in `../projects.md` (first token before the
  colon).
- `Feature:` starts the description; everything below it is the task prompt.
- The filename becomes the branch: `feature-<slugified-name>`. It must not
  collide with an existing branch or worktree name in the project.

## Lifecycle

- `features/ready/` — pending; picked up within 10 minutes.
- `features/.dispatched/` — handed to an agent successfully.
- `features/failed/` — fix and move back to `ready/` to retry.
- `features/.dispatch.log` — per-run log of decisions.
- `features/.lock/` — guards against overlapping runs; safe to delete when
  no dispatcher process is alive.

## Concurrency

At most `max_in_flight` delegated sessions stay open (default 5). Edit
`../bin/dispatch.conf` to change it; the next run uses the new value.
