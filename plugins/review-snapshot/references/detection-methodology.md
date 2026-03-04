# Test Runner Detection Methodology

A three-step process for identifying the correct test command for any project. This is a methodology guide — use judgment and adapt to what the codebase reveals.

## Step 1: Identify Technology Stacks

Scan the repository root and common locations for ecosystem markers.

### Language indicators

Look for dominant file extensions:
- `.lua` → Lua (check for Neovim plugin indicators)
- `.py` → Python
- `.rs` → Rust
- `.go` → Go
- `.ts`, `.tsx`, `.js`, `.jsx` → JavaScript/TypeScript
- `.cs` → C#/.NET
- `.java`, `.kt` → JVM
- `.rb` → Ruby
- `.ex`, `.exs` → Elixir
- `.swift` → Swift

### Package manifests

These confirm the ecosystem and may contain test config:
- `package.json` → Node.js/JS/TS
- `pyproject.toml`, `setup.py`, `setup.cfg` → Python
- `Cargo.toml` → Rust
- `go.mod` → Go
- `*.csproj`, `*.sln` → .NET
- `pom.xml`, `build.gradle`, `build.gradle.kts` → JVM
- `Gemfile` → Ruby
- `mix.exs` → Elixir

### Framework indicators

Narrow down the stack further:
- `init.lua` + `lua/` directory + plenary in deps → Neovim plugin
- `manage.py` → Django
- `next.config.js` → Next.js
- `angular.json` → Angular
- `Cargo.toml` with `[lib]` + `tests/` → Rust library

## Step 2: Research Test Runners

For each detected stack, identify the standard test framework(s). Use built-in knowledge first; web search if the stack is unfamiliar.

### Common stack → runner mappings (starting points, not exhaustive)

| Stack | Common runners | Config files |
|-------|---------------|--------------|
| Neovim plugin | plenary.nvim, busted | `tests/minimal_init.lua`, `.busted` |
| Python | pytest, unittest, nose2 | `pyproject.toml [tool.pytest]`, `pytest.ini`, `conftest.py`, `tox.ini` |
| Rust | cargo test (built-in) | `Cargo.toml` |
| Go | go test (built-in) | `*_test.go` files |
| Node.js/TS | jest, vitest, mocha, ava | `jest.config.*`, `vitest.config.*`, `.mocharc.*` |
| .NET | xUnit, NUnit, MSTest | `*.csproj` with test SDK references |
| Ruby | RSpec, minitest | `.rspec`, `spec/`, `test/` |
| Elixir | ExUnit (built-in) | `test/test_helper.exs` |
| JVM | JUnit, TestNG | `src/test/` |

**This table is a starting point.** Always verify against actual codebase evidence.

## Step 3: Search Codebase for Evidence

Look for concrete proof of which runner is actually used. Search in priority order:

### 1. Makefile / Taskfile targets

```
grep -E '^test.*:' Makefile
grep -E 'test' Taskfile.yml
```

These often wrap the actual test command and are the most reliable source — they represent the project's intended invocation.

### 2. CI configuration

```
.github/workflows/*.yml
.gitlab-ci.yml
.circleci/config.yml
Jenkinsfile
```

Look for `run: ` or `script:` lines that invoke test commands.

### 3. Test runner config files

Their presence confirms the runner:
- `jest.config.js` → Jest
- `vitest.config.ts` → Vitest
- `conftest.py` → pytest
- `tests/minimal_init.lua` → plenary.nvim
- `.rspec` → RSpec

### 4. Test dependencies in manifests

- `package.json` → check `devDependencies` for `jest`, `vitest`, `mocha`
- `pyproject.toml` → check `[tool.pytest]` or `[project.optional-dependencies]`
- `Cargo.toml` → check `[dev-dependencies]` for test crates
- `*.csproj` → check for `Microsoft.NET.Test.Sdk`

### 5. Test directories

Common conventions:
- `tests/`, `test/`, `spec/` — most languages
- `__tests__/` — JavaScript (Jest convention)
- `src/test/` — JVM
- `*_test.go` — Go (files, not directories)

## Handling Ambiguous Cases

### Multiple test runners detected

Example: `jest` in devDependencies AND `vitest.config.ts` exists.

**Resolution:** Check which one CI uses. Check `package.json` scripts. Ask the user which to use for the snapshot — present findings with evidence.

### Multiple test suites (unit + integration + e2e)

**Resolution:** Prefer the fastest suite (usually unit tests) for snapshots. Present all options to user. The snapshot runs on every Stop — it should be fast.

### Monorepo with multiple stacks

**Resolution:** Look for a root-level test command first (`Makefile`, root `package.json` scripts). If none, identify the primary project or ask the user which sub-project to test.

### No tests found

**Resolution:** Set `test_command` to empty/omit from config. The hook will output `"available": false`. Inform user they can add a test command to config later.

### Makefile wraps unknown command

If `make test` exists but you can't determine what it runs:

**Resolution:** Use `make test` as the command with `"test_runner": "make"`. The wrapper is good enough — the hook just needs a command to run.

## Constructing the Test Command

Once the runner is identified, construct a command that:

1. **Runs from the repo root** — the hook `cd`s to git toplevel before executing
2. **Exits with meaningful status** — 0 for pass, non-zero for failure
3. **Produces output on stdout/stderr** — the hook captures the last line
4. **Completes reasonably fast** — runs on every Stop, should finish in under 60 seconds

### Examples

| Runner | Example command |
|--------|----------------|
| plenary | `cd nvim && nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"` |
| pytest | `python -m pytest --tb=short -q` |
| cargo test | `cargo test --quiet` |
| go test | `go test ./... -count=1` |
| jest | `npx jest --silent` |
| vitest | `npx vitest run --reporter=verbose` |
| make | `make test` |
| dotnet | `dotnet test --verbosity quiet` |
