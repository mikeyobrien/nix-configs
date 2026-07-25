# Android Emacs

Vanilla Emacs 30 configuration for the native GNU Emacs Android app. It uses
Termux tools without requiring a second Termux build of Emacs.

## Install

From this directory in Termux:

```sh
bash install.sh
```

The installer copies the configuration to `~/.emacs.d`, installs pinned symbol
and monochrome emoji fonts, and links the Android app's Emacs directory to the
Termux-managed configuration. Existing Android Emacs state is moved to a
timestamped backup before the link is created.

Copy `local.el.example` to `~/.emacs.d/local.el` for private, device-specific
settings. `local.el` is ignored by Git. The Obsidian vault can also be supplied
through `OBSIDIAN_VAULT`.

Restart Emacs after installing or updating fonts.

## What is configured

- Touch-friendly home page and Phone menu
- Termux shell, executable path, and shared-storage access
- Bottom extra-key strip: `ESC CTRL ALT TAB ← ↓ ↑ →`
- Gboard/Samsung Keyboard IME composition and glide typing
- Responsive Markdown reading mode for phone, Fold, rotation, and split screen
- Obsidian note jumping, search, wikilinks, backlinks, and vault home
- Vertico, Consult, Embark, Corfu, Ef themes, and small visual refinements
- Isolated backups, auto-saves, recent files, and Customize state

Packages are installed on first startup through `package.el` and `use-package`.

## Useful controls

- `C-c h` — home page
- `Phone → Extra keys bar` — toggle the bottom key strip
- `Phone → Refresh buffer` or `F5` — reload a file and reapply its display mode
- Volume Down — show the Android keyboard
- `C-c t` — toggle dark/light themes
- `C-c w h` — wiki home
- `C-c w p` — choose a wiki note
- `C-c w s` — search the wiki
- `C-c C-l` — insert an Obsidian wikilink while editing a vault note
- `C-c C-o` — follow the link at point
- `C-c C-b` — choose a backlink
- `e` — edit a Markdown document opened in reading mode
- `C-c C-r` — return to Markdown reading mode

The extra-key strip is hidden on the home page and in Markdown reading mode.
`CTRL` and `ALT` modify the next typed key; `ALT` acts as Emacs Meta.

## Files

- `early-init.el` — startup and frame defaults
- `init.el` — complete configuration
- `local.el.example` — private-path template
- `install.sh` — Termux/Android installer
