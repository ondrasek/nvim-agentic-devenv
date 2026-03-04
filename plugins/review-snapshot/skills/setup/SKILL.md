# Review Snapshot — Setup & Maintenance Skill

Configure the review-snapshot hook for any project. Detects test runners, writes config, installs the hook.

## Triggers

- "set up review snapshot"
- "configure review hook"
- "audit review snapshot"
- "update review-snapshot hook"
- "configure agentic review"
- "add review dashboard"

## Overview

The review-snapshot hook runs on every Claude Code Stop event. It generates a folder of markdown reports covering changes, tests, conversation transcript, and PR statuses. Reports are written to `.claude/reviews/latest/` (overwritten each session). This skill handles one-time setup — detecting the project's test runner and writing the config that drives the hook.

## Modes

Determine mode automatically based on current state:

### Construct (no hook or config exists)

1. **Detect test runner** — follow the detection methodology in `references/detection-methodology.md`
2. **Confirm with user** — present findings, ask which test command to use
3. **Write config** — create `.claude/reviews/config.json`:
   ```json
   {
     "sha": "<current HEAD short SHA>",
     "test_command": "<detected command>",
     "test_runner": "<runner name>"
   }
   ```
4. **Install hook script** — copy the hook from this plugin's `hooks/review-snapshot.sh` to `.claude/hooks/`
5. **Register Stop hook** in `.claude/settings.json` (if not present):
   ```json
   {
     "hooks": {
       "Stop": [{
         "hooks": [{
           "type": "command",
           "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/review-snapshot.sh",
           "timeout": 10
         }]
       }]
     }
   }
   ```
   If the plugin is installed via marketplace, the hook may already be registered by the plugin system.
6. **Add `.claude/reviews/` to `.gitignore`** (if not present)

### Audit (hook exists)

1. Re-run detection methodology
2. Compare detected runner against `config.json`
3. Check hook script is current version
4. Check `settings.json` has the Stop hook registered
5. Check `.gitignore` includes `.claude/reviews/`
6. **Report gaps** — list what matches and what doesn't

### Update (fix gaps found by audit)

1. Update `config.json` with re-detected test runner
2. Update hook script if outdated
3. Fix missing registrations in `settings.json` or `.gitignore`

## Detection Methodology

Follow the detailed guide in `references/detection-methodology.md`. Summary:

1. **Identify technology stacks** — scan for language files, package manifests, framework indicators
2. **Research test runners** — use built-in knowledge (and web search if needed) to identify standard test frameworks for detected stacks
3. **Search codebase for evidence** — look for test runner configs, test dependencies in manifests, test directories, Makefile targets, CI configs

## Config Schema

File: `.claude/reviews/config.json`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sha` | string | yes | Baseline commit SHA (short) for diff comparison |
| `test_command` | string | no | Shell command to run tests. Omit if no tests available. |
| `test_runner` | string | no | Runner name (e.g., `"plenary"`, `"pytest"`, `"jest"`). Omit if no tests. |

## Hook Output

The hook writes markdown reports to `.claude/reviews/latest/`:

| File | Content |
|------|---------|
| `00-summary.md` | At-a-glance overview with links to other reports |
| `01-changes.md` | Changed files list, insertions/deletions |
| `02-tests.md` | Test runner, exit code, full output |
| `03-conversation.md` | User/assistant dialogue from session transcript |
| `04-pull-requests.md` | Current branch PR + recent open PRs |

After generating reports, the hook opens `00-summary.md` in the running nvim instance with neo-tree revealed.

## Important Notes

- The hook runs in background (`& disown`) — it must not block Claude's exit
- Hook timeout is 10 seconds (only the synchronous change-detection part)
- Always confirm test command with user before writing config — auto-detection can be wrong
- If multiple test runners are found (e.g., unit + integration), ask user which to use for snapshots
- PR status requires `gh` CLI — graceful fallback if unavailable
- Conversation transcript requires `jq` and `CLAUDE_PROJECT_DIR` — graceful fallback if unavailable
