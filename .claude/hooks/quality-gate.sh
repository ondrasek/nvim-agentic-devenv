#!/usr/bin/env bash
# Quality gate — runs on Stop hook (exit 2 = block, exit 0 = pass)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

failed=0

# 1. Tests (plenary.nvim)
echo "=== Tests ==="
if command -v nvim >/dev/null 2>&1; then
    cd nvim
    if nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" 2>&1; then
        echo "PASS: tests"
    else
        echo "FAIL: tests"
        failed=1
    fi
    cd ..
else
    echo "SKIP: nvim not found"
fi

if [ "$failed" -eq 1 ]; then
    echo "Quality gate FAILED at: tests"
    exit 2
fi

# 2. Selene (linter)
echo "=== Selene ==="
if command -v selene >/dev/null 2>&1; then
    if selene nvim/lua/ nvim/init.lua; then
        echo "PASS: selene"
    else
        echo "FAIL: selene"
        failed=1
    fi
else
    echo "SKIP: selene not installed"
fi

if [ "$failed" -eq 1 ]; then
    echo "Quality gate FAILED at: selene"
    exit 2
fi

# 3. StyLua (formatter check)
echo "=== StyLua ==="
if command -v stylua >/dev/null 2>&1; then
    if stylua --check nvim/lua/ nvim/init.lua; then
        echo "PASS: stylua"
    else
        echo "FAIL: stylua --check (files not formatted)"
        failed=1
    fi
else
    echo "SKIP: stylua not installed"
fi

if [ "$failed" -eq 1 ]; then
    echo "Quality gate FAILED at: stylua"
    exit 2
fi

# 4. Lizard (complexity)
echo "=== Lizard ==="
if command -v lizard >/dev/null 2>&1; then
    if lizard nvim/lua/ --CCN 20 --warnings_only; then
        echo "PASS: lizard"
    else
        echo "FAIL: lizard (complexity threshold exceeded)"
        failed=1
    fi
else
    echo "SKIP: lizard not installed"
fi

if [ "$failed" -eq 1 ]; then
    echo "Quality gate FAILED at: lizard"
    exit 2
fi

# 5. Security (non-blocking, informational only)
echo "=== Security (informational) ==="
security_issues=0
# Check for os.execute, loadstring, load() with string arg — but not io.open (legitimate use)
if grep -rn 'os\.execute\|loadstring\|[^io.]load(' nvim/lua/ nvim/init.lua 2>/dev/null; then
    echo "NOTE: potential security-sensitive patterns found (review above)"
    security_issues=1
fi
if [ "$security_issues" -eq 0 ]; then
    echo "PASS: no suspicious patterns"
fi

echo ""
echo "Quality gate PASSED"
exit 0
