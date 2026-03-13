# Shell functions for nvim-agentic-devenv
# Source this file from .zshrc or .bashrc

# Launch nvim with review-snapshot dashboard support.
# Listens on a per-repo socket at .claude/.nvim-socket so the
# review-snapshot Stop hook can push reports into this instance.
nvim-review() {
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$git_root" ]]; then
        echo "nvim-review: not in a git repository" >&2
        return 1
    fi
    if [[ ! -d "$git_root/.claude" ]]; then
        echo "nvim-review: no .claude/ directory in $git_root" >&2
        return 1
    fi
    local sock="$git_root/.claude/.nvim-socket"
    nvim --listen "$sock" "$@"
    # Clean up socket on exit (in case nvim didn't)
    rm -f "$sock"
}
