#!/usr/bin/env bash
# Track the configs `make copy` installed in chezmoi: add exactly the files this repo installs, and forget
# entries that `make copy` mirrored away (otherwise a later `chezmoi apply` resurrects them).
#
# chezmoi may be configured with git.autocommit / git.autopush: then every add/forget is committed AND
# PUSHED to the dotfiles remote. The plan below says so, and nothing is changed without a "y".
#
#   setup/chezmoi-sync.sh            show the plan, ask, then apply
#   setup/chezmoi-sync.sh --dry-run  show the plan only
#   setup/chezmoi-sync.sh --yes      apply without asking (still prints the plan)
set -euo pipefail

mode=ask
case "${1:-}" in
    --dry-run) mode=dry ;;
    --yes) mode=yes ;;
    "") ;;
    *) echo "usage: $0 [--dry-run|--yes]" >&2; exit 2 ;;
esac

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi is not installed: nothing to track."
    exit 0
fi

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
conf="$HOME/.config"

# What `make copy` installs (see NVIM_RSYNC_EXCLUDES in the Makefile): tracked nvim/ files minus the excluded
# ones, plus tmux.conf. Ghostty is seed-only and never tracked here.
files=()
while IFS= read -r f; do
    rel="${f#nvim/}"
    case "$rel" in
        tests/* | .claude/* | lazy-lock.json | *.log | .nvimlog) continue ;;
    esac
    [ -e "$conf/nvim/$rel" ] && files+=("$conf/nvim/$rel")
done < <(git -C "$repo" ls-files nvim)
[ -e "$conf/tmux/tmux.conf" ] && files+=("$conf/tmux/tmux.conf")

managed="$(chezmoi managed --path-style absolute 2>/dev/null || true)"
new=0
known=0
for f in ${files[@]+"${files[@]}"}; do
    if grep -qxF "$f" <<<"$managed"; then known=$((known + 1)); else new=$((new + 1)); fi
done

# Tracked by chezmoi but gone from the target ("DA"): what the mirror removed
stale=()
while IFS= read -r line; do
    [ "${line%% *}" = "DA" ] || continue
    path="${line#DA }"
    case "$path" in
        .config/nvim/* | .config/tmux/*)
            # A forgotten directory takes its files with it: skip children of an entry already listed
            skip=0
            for s in ${stale[@]+"${stale[@]}"}; do
                case "$HOME/$path" in "$s"/*) skip=1 ;; esac
            done
            [ "$skip" = 1 ] || stale+=("$HOME/$path")
            ;;
    esac
done < <(chezmoi status 2>/dev/null || true)

autopush="$(chezmoi dump-config --format=json 2>/dev/null | jq -r '.git.autopush // false' 2>/dev/null || echo false)"
autocommit="$(chezmoi dump-config --format=json 2>/dev/null | jq -r '.git.autocommit // false' 2>/dev/null || echo false)"
remote="$(git -C "$(chezmoi source-path)" remote get-url origin 2>/dev/null || echo '(none)')"

echo "chezmoi sync plan"
echo "  add/update : ${#files[@]} files this repo installs ($known already tracked, $new new)"
echo "  forget     : ${#stale[@]} stale entries that make copy removed from ~/.config"
for s in ${stale[@]+"${stale[@]}"}; do echo "                 - ${s#"$HOME"/}"; done
echo "  chezmoi git: autocommit=$autocommit autopush=$autopush  remote=$remote"
if [ "$autopush" = "true" ]; then
    echo "  WARNING    : this will commit AND PUSH to $remote"
fi

[ "$mode" = dry ] && { echo "(dry run: nothing changed)"; exit 0; }

if [ "$mode" = ask ]; then
    read -r -p "Apply? [y/N] " answer
    [ "$answer" = "y" ] || { echo "Aborted: nothing changed."; exit 0; }
fi

if [ "${#files[@]}" -gt 0 ]; then
    chezmoi add "${files[@]}"
fi
if [ "${#stale[@]}" -gt 0 ]; then
    chezmoi forget --force "${stale[@]}"
fi
echo "Done."
