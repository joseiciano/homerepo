---
name: setup-projects
description: Build or refresh ./projects.md, the name-to-path map of local repositories under ~/Documents/workspace. Use for /setup-projects or when a project is missing from projects.md.
disable-model-invocation: true
---

# setup-projects

Write `./projects.md` in the homerepo root: one line per project, `<name>: <absolute path>`, sorted case-insensitively by name. Other agents resolve delegation targets from this file.

## Steps

1. List the direct children of `~/Documents/workspace`. Expand `~` to the absolute path.
2. Classify each child. A child is a project when it is one of:
   - a git checkout (`.git` file or directory)
   - a bare repository (`HEAD` file and `refs` directory)
   - a parent of worktrees (a subdirectory with a `.git` file, or a `.bare` directory)
   Skip every other child.
3. Read the existing `./projects.md` when present. Keep its lines for projects that still exist, so hand-written names survive. Add lines for new projects. Report lines whose path no longer exists and remove them.
4. Write the file. Each line holds the directory name as the project name and the absolute path.
5. Verify: every path in the file exists, and every project found in step 2 has a line. Print the final list and the added and removed names.

Done when the verification in step 5 passes.
