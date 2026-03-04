# review-snapshot

A Claude Code plugin that configures post-session review snapshots. Detects test runners, writes config, and installs a Stop hook that captures changed files, diff stats, and test results after every session.

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

**Hook (every Stop):** Reads config, runs the test command, captures diff stats, and writes a JSON snapshot to `.claude/reviews/`.

## Snapshot output

```json
{
  "version": 1,
  "timestamp": "2026-03-04T10:30:00Z",
  "baseline_sha": "abc1234",
  "current_sha": "def5678",
  "changed_files": ["src/main.py", "tests/test_main.py"],
  "diff_stat": {
    "raw": "2 files changed, 42 insertions(+), 7 deletions(-)",
    "files_changed": 2,
    "insertions": 42,
    "deletions": 7
  },
  "test_results": {
    "available": true,
    "runner": "pytest",
    "exit_code": 0,
    "output": "3 passed in 0.12s"
  }
}
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
