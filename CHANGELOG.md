# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-04-07

### Added
- Initial release.
- `bin/i3-quickphrase` typing tool. Subcommands: `<phrase-name>` (type),
  `doctor` (diagnostics), `--version`, `--help`.
- `lib/validate.sh` sourced phrase file/name validators (printable ASCII
  allowlist, symlink rejection, owner check).
- `phrases/comprehensive.txt` example phrase (87 bytes exact, no trailing
  LF, mapped to `Alt+M`).
- `dist/i3-quickphrase.conf` i3 binding snippet with extension instructions.
- `install.sh`: idempotent, refuses root, validates i3 config with `i3 -C`
  before atomic swap, BEGIN/END sentinels, symlink-based file management,
  `chmod 700/600` on phrases directory and files.
- `uninstall.sh`: symmetric to install, surgical `sed` block-delete using
  the BEGIN/END sentinels, repo directory left intact.
- `xdotool type --clearmodifiers --delay 12 --window <captured-id> --file`
  injection mechanism (per Researcher and Pentester recommendations).
- `flock` single-shot guard against key-repeat and double-press reentry.
- Optional `I3_QUICKPHRASE_ALLOWED_CLASSES` env var allowlist (default
  `*` = allow any window).
- `.editorconfig`: `trim_trailing_whitespace = false` and
  `insert_final_newline = false` for `phrases/*.txt` to protect the
  trailing-space convention.
- `.gitattributes`: `phrases/*.txt -text` to prevent git LF normalization.
- `.github/workflows/ci.yml`: shellcheck on all shell scripts plus
  phrase-content allowlist and bidi-control detection.
- `README.md`, `SECURITY.md`, `DESIGN.md`, `LICENSE` (MIT).

### Security
- Strict ASCII allowlist on phrase content rejects ANSI escapes, OSC 52
  clipboard exfil, Trojan Source bidi controls, and zero-width characters.
- Phrase names validated against `^[a-z][a-z0-9_-]*$` to prevent path
  traversal.
- `xdotool --file` mode (never argv) prevents content leaking via
  `ps auxf` and prevents shell metacharacter injection.
- Captured-window-ID + `--window` defeats focus-drift races.
- Refuse-root install/uninstall.

[0.1.0]: https://github.com/cr4shOverr1de/i3-quickphrase/releases/tag/v0.1.0
