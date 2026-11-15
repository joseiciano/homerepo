# Home repo targets.
# make setup-projects — refresh projects.md (runs the setup-projects skill)
# make setup-cron     — install the feature dispatcher cron entry if absent
# make recover        — restore worktree agents orphaned by a reboot/crash

HOMEREPO := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
CRON_LINE := */10 * * * * $(HOMEREPO)/bin/dispatch-features.sh >> $(HOMEREPO)/features/.cron.log 2>&1

.PHONY: setup-projects setup-cron recover

# The setup-projects skill (.claude/skills/setup-projects/SKILL.md) defines the
# exact steps; claude -p executes it non-interactively. It must list
# ~/Documents/workspace, so sandboxing is off for this run only.
setup-projects:
	cd $(HOMEREPO) && claude -p "/setup-projects" --dangerously-skip-permissions

setup-cron:
	@printf '%s\n' '$(CRON_LINE)' > /tmp/homerepo-cron-line
	@if crontab -l 2>/dev/null | grep -qF "dispatch-features.sh"; then \
		echo "cron entry already installed:"; \
		crontab -l | grep -F "dispatch-features.sh"; \
	elif [ -n "$$(crontab -l 2>/dev/null)" ]; then \
		{ crontab -l; printf '%s\n' "$$(cat /tmp/homerepo-cron-line)"; } | crontab -; \
		echo "cron entry installed:"; \
		crontab -l | grep -F "dispatch-features.sh"; \
	else \
		cat /tmp/homerepo-cron-line | crontab -; \
		echo "cron entry installed (new crontab):"; \
		crontab -l; \
	fi
	@rm -f /tmp/homerepo-cron-line

# workmux resurrect is repo-scoped: it matches state files against the
# worktrees of the repo in the current directory, so run it once per project.
recover:
	@for path in $$(sed 's/^[^:]*:[[:space:]]*//' projects.md); do \
		[ -d "$$path" ] || continue; \
		git -C "$$path" rev-parse --git-dir >/dev/null 2>&1 || continue; \
		echo "== $$path"; \
		(cd "$$path" && workmux resurrect 2>&1 | grep -v '^ *(' || true); \
	done
