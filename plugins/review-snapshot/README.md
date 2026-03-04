# review-snapshot

A Claude Code plugin that configures post-session review dashboards. Detects test runners, writes config, and installs a Stop hook that generates markdown reports covering changes, tests, conversation transcript, and PR statuses after every session.

## Installation

### From marketplace

```
/plugin marketplace add ondrasek/nvim-agentic-devenv
/plugin install review-snapshot@agentic-devenv-plugins
```

### Manual

```
claude --plugin-dir ./plugins/review-snapshot
```

## Usage

Invoke the setup skill:

```
/review-snapshot:setup
```

Or use natural language triggers:
- "set up review snapshot"
- "configure review hook"
- "audit review snapshot"

## How it works

**Skill (one-time setup):** Analyzes your codebase to detect technology stacks and test runners. Writes a config file (`.claude/reviews/config.json`) and installs the hook.

**Hook (every Stop):** Reads config, runs tests, queries PR status, parses session transcript, and generates markdown reports to `.claude/reviews/latest/`. Opens the summary in nvim with neo-tree.

## Dashboard output

Reports are written to `.claude/reviews/latest/` (overwritten each session):

```
.claude/reviews/latest/
├── 00-summary.md          # At-a-glance overview with links
├── 01-changes.md          # Changed files, diff stats
├── 02-tests.md            # Test runner, exit code, output
├── 03-conversation.md     # User/assistant dialogue
└── 04-pull-requests.md    # Current branch PR + open PRs
```

### Example summary

```markdown
# Session Review — 2026-03-04T10:30:00Z

## At a Glance
- **Branch:** feature/review-dashboard
- **Baseline:** `abc1234` → **Current:** `def5678`
- **Files changed:** 2 (+42 / -7)
- **Tests:** PASS (pytest)
- **Open PRs:** 1

## Reports
- [Changes](01-changes.md)
- [Tests](02-tests.md)
- [Conversation](03-conversation.md)
- [Pull Requests](04-pull-requests.md)
```

## Supported stacks

The detection methodology identifies test runners for any stack including:
- Neovim plugins (plenary.nvim)
- Python (pytest, unittest)
- Rust (cargo test)
- Go (go test)
- Node.js/TypeScript (jest, vitest, mocha)
- .NET (xUnit, NUnit)
- And more — see `references/detection-methodology.md`
