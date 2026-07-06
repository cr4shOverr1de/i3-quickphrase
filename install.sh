#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# i3-quickphrase installer — idempotent, refuses root, validates before reload.
# Session-aware since v0.2.0: X11 wires i3 automatically; Wayland symlinks
# the binary and prints manual bind wiring (compositor configs are too
# personal to machine-edit, and there is no `i3 -C`-grade validator to
# hide behind).

set -euo pipefail

PROG="i3-quickphrase"

# Refuse to run as root: would leave root-owned files in $HOME and create
# a confusing permission tangle later.
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "$PROG: refusing to run as root. Run as your normal user." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOCAL_BIN="${HOME}/.local/bin"
I3_CONFIG_DIR="${HOME}/.config/i3"
I3_CONFIG="${I3_CONFIG_DIR}/config"
I3_DROPIN_DIR="${I3_CONFIG_DIR}/config.d"
I3_DROPIN="${I3_DROPIN_DIR}/i3-quickphrase.conf"

# Same selection rule as bin/i3-quickphrase: a Wayland session always gets
# the Wayland path — xdotool there would only reach XWayland clients.
SESSION="x11"
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  SESSION="wayland"
fi

echo "==> $PROG installer"
echo "    Repo:    $REPO_ROOT"
echo "    Session: $SESSION"
echo "    Target:  $LOCAL_BIN/i3-quickphrase"
if [[ "$SESSION" == "x11" ]]; then
  echo "    i3 conf: $I3_CONFIG"
fi
echo

# ---- preflight ----
echo "==> Checking required dependencies"
missing=()
if [[ "$SESSION" == "wayland" ]]; then
  required=(wtype)
  hint="Try: sudo pacman -S wtype   (Debian/Ubuntu: sudo apt install wtype)"
else
  required=(xdotool i3-msg i3)
  hint="Try: sudo apt install xdotool i3"
fi
for cmd in "${required[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "    Missing required commands: ${missing[*]}" >&2
  echo "    $hint" >&2
  exit 1
fi

echo "==> Checking optional dependencies"
if [[ "$SESSION" == "wayland" ]]; then
  optional=(hyprctl notify-send flock)
else
  optional=(xprop notify-send flock)
fi
for cmd in "${optional[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "    [ok] $cmd"
  else
    echo "    [missing — recommended] $cmd"
  fi
done

# ---- phrase file integrity ----
echo "==> Verifying phrase file integrity"
expected=87
actual="$(wc -c < "$REPO_ROOT/phrases/comprehensive.txt")"
if [[ "$actual" -eq "$expected" ]]; then
  echo "    phrases/comprehensive.txt: $actual bytes (expected $expected) [ok]"
else
  echo "    WARNING: phrases/comprehensive.txt is $actual bytes, expected $expected." >&2
  echo "    Trailing space may have been stripped by an editor. Continuing anyway." >&2
fi

# ---- symlink the binary ----
echo "==> Symlinking binary into $LOCAL_BIN"
mkdir -p "$LOCAL_BIN"
ln -sfn "$REPO_ROOT/bin/i3-quickphrase" "$LOCAL_BIN/i3-quickphrase"
echo "    $LOCAL_BIN/i3-quickphrase -> $REPO_ROOT/bin/i3-quickphrase"

if [[ "$SESSION" == "x11" ]]; then
  # ---- i3 config exists ----
  if [[ ! -f "$I3_CONFIG" ]]; then
    echo "    i3 config not found at $I3_CONFIG" >&2
    exit 1
  fi

  # ---- symlink the i3 dropin ----
  echo "==> Symlinking i3 dropin into $I3_DROPIN_DIR"
  mkdir -p "$I3_DROPIN_DIR"
  ln -sfn "$REPO_ROOT/dist/i3-quickphrase.conf" "$I3_DROPIN"
  echo "    $I3_DROPIN -> $REPO_ROOT/dist/i3-quickphrase.conf"

  # ---- add include block to main i3 config ----
  if grep -qF "BEGIN i3-quickphrase" "$I3_CONFIG"; then
    echo "==> Include block already present in $I3_CONFIG (skipping)"
  else
    echo "==> Adding include block to $I3_CONFIG (atomic, validated)"
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    cp "$I3_CONFIG" "$tmp"
    cat >> "$tmp" <<'EOF'

# BEGIN i3-quickphrase
include ~/.config/i3/config.d/i3-quickphrase.conf
# END i3-quickphrase
EOF
    if i3 -C -c "$tmp" >/dev/null 2>&1; then
      mv "$tmp" "$I3_CONFIG"
      trap - EXIT
      echo "    Validated and installed."
    else
      echo "    ERROR: i3 -C validation failed on the modified config." >&2
      echo "    No changes made to $I3_CONFIG." >&2
      exit 1
    fi
  fi
else
  # ---- Wayland: manual bind wiring (deliberately no config auto-edit) ----
  echo "==> Wayland session: wire the binds yourself (one-time copy/paste)"
  echo "    Hyprland (Lua parser):   $REPO_ROOT/dist/hyprland-binds.lua"
  echo "    Hyprland (classic conf): $REPO_ROOT/dist/hyprland.conf"
  echo "    Then: hyprctl reload"
fi

# ---- tighten phrase permissions ----
echo "==> Tightening phrase file permissions"
chmod 700 "$REPO_ROOT/phrases" 2>/dev/null || true
chmod 600 "$REPO_ROOT"/phrases/*.txt 2>/dev/null || true

# ---- reload / wrap up ----
if [[ "$SESSION" == "x11" ]]; then
  echo "==> Reloading i3"
  if i3-msg reload >/dev/null 2>&1; then
    echo
    echo "✓ Installed."
    echo "  Test:        focus a kitty window, press Alt+M"
    echo "  Diagnostics: i3-quickphrase doctor"
    echo "  Uninstall:   $REPO_ROOT/uninstall.sh"
  else
    echo "    WARNING: i3-msg reload failed. You may need to reload i3 manually." >&2
  fi
else
  echo
  echo "✓ Installed (binary + phrases)."
  echo "  Next:        add the binds (see above), then hyprctl reload"
  echo "  Test:        focus a text field, press Alt+M"
  echo "  Diagnostics: i3-quickphrase doctor"
  echo "  Uninstall:   $REPO_ROOT/uninstall.sh"
fi
