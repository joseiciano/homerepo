# Home Repo

The homerepo is the dispatch base. From here, the main agent delegates work on other repositories. It never does that work itself.

## Agent Harness

claude-code

The harness is the agent that runs inside each delegated workmux session. Pass it to `workmux add -a <harness>`.

## Projects

`./projects.md` maps each project name to its local repository path. Resolve the target project there before delegating.

## Delegation workflow

The main agent is a dispatcher. For every task in a project:

1. Resolve the project path in `./projects.md`.
2. Spawn one Task agent in the background (`run_in_background: true`). This agent is the orchestrator for the task.
3. The orchestrator starts a workmux session for the project with the Agent Harness:
   `workmux add <branch> -a claude-code -b --parent-session homerepo -p "<task prompt>"` run from the project repo. The `homerepo` parent session marks the session as delegated from here; `/list-sessions` depends on it.
4. The orchestrator owns the task from there: it decomposes, monitors the session, answers routine questions, verifies the result, and commits.
5. The orchestrator ends with exactly one report: done, or blocked on a question.
6. The main agent relays the report to the user. For a question, it asks the user, then sends the answer back to the same orchestrator with `SendMessage`.

Independent tasks get independent orchestrators, spawned in one message so they run concurrently.

### Orchestrator brief

Every orchestrator prompt contains:

- Project name and repository path
- Task, with observable acceptance criteria
- Constraints from the user
- The reporting rule: return only on done, or on a question that needs the user

### Question propagation

A question is any decision the orchestrator cannot resolve from the task, the code, or sensible defaults. The orchestrator returns the question with its context and options. It does not guess critical details.

## Working within a repository

Repositories are usually bare. Work happens in a worktree. If the session is not in one, `workmux add` creates it. Branch from `staging` when it exists, otherwise from `main`, after pulling from remote.

## Session management

`workmux` manages sessions and worktrees. Each delegated task has one workmux session.
