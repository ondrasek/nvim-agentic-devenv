# iTerm2 Configuration

## Cmd+N → Alt+N Key Mappings (for tmux window switching)

The tmux config uses `Alt+1` through `Alt+9` to switch windows. Ghostty handles this
via its config file, but iTerm2 requires manual setup.

### Setup Steps

1. Open **iTerm2 → Settings → Profiles → Keys → Key Mappings**
2. Click **+** to add a new key mapping for each of `Cmd+1` through `Cmd+9`:

| Shortcut | Action          | Esc+ value |
|----------|-----------------|------------|
| Cmd+1    | Send Escape Sequence | `1`   |
| Cmd+2    | Send Escape Sequence | `2`   |
| Cmd+3    | Send Escape Sequence | `3`   |
| Cmd+4    | Send Escape Sequence | `4`   |
| Cmd+5    | Send Escape Sequence | `5`   |
| Cmd+6    | Send Escape Sequence | `6`   |
| Cmd+7    | Send Escape Sequence | `7`   |
| Cmd+8    | Send Escape Sequence | `8`   |
| Cmd+9    | Send Escape Sequence | `9`   |

3. For each mapping:
   - **Action:** "Send Escape Sequence"
   - **Esc+:** the number (e.g., `1` for Cmd+1)

This sends `\x1b1` through `\x1b9` (Alt+N escape sequences), which tmux picks up
as `M-1` through `M-9` for window switching.

### Additional Recommended Settings

- **Profiles → Text → Font:** JetBrainsMono Nerd Font, 15pt
- **Profiles → General → Command:** `/bin/zsh` (login shell)
- **Profiles → Terminal → Report Terminal Type:** `xterm-256color`
- **General → Selection → Applications in terminal may access clipboard:** enabled
