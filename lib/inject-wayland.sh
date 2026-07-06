#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# i3-quickphrase Wayland injection backend — sourced by bin/i3-quickphrase.
#
# wtype speaks zwp_virtual_keyboard_v1, supported by wlroots-lineage
# compositors (Hyprland, sway, river). DESIGN.md slotted this as v0.3.0;
# it shipped early, in v0.2.0, when the maintainer's daily driver moved
# from Debian/i3/X11 to Arch/Hyprland/Wayland. wtype was chosen over
# ydotool (needs a daemon plus /dev/uinput privileges) and dotool (same
# uinput story): wtype is daemon-free and protocol-native.
#
# Two deliberate downgrades from the X11 backend, both forced by the
# protocol, both documented in SECURITY.md "Wayland differences":
#
# 1. NO WINDOW PINNING. X11 captures the active window id and passes
#    --window to every xdotool call, so focus drift after the trigger is
#    harmless. The virtual-keyboard protocol has no per-window addressing —
#    keys land wherever keyboard focus is when they arrive. Partial
#    mitigation: the class allowlist is evaluated against the focused
#    window at fire time (via hyprctl, when available).
#
# 2. NO SYNTHETIC MODIFIER KEYUP. A virtual keyboard cannot release keys
#    held on another (physical) device, so the X11 keyup trick has no
#    equivalent. The bind MUST fire on key release (Hyprland Lua parser:
#    `{ release = true }`; classic syntax: `bindr`), and inject_prepare
#    sleeps I3_QUICKPHRASE_MOD_SETTLE seconds (default 0.25) so a
#    still-held Alt clears before the first character arrives. Cheap
#    insurance: costs a quarter second, prevents Alt+<char> chords.

INJECT_BACKEND="wayland"

QP_MOD_SETTLE="${I3_QUICKPHRASE_MOD_SETTLE:-0.25}"

# Focused-window class via hyprctl. The sed pattern is line-anchored so
# "initialClass" in the same JSON blob cannot shadow "class". Returns
# nothing when hyprctl is unavailable (sway etc. — allowlist unusable).
_qp_wl_active_class() {
  command -v hyprctl >/dev/null 2>&1 || return 1
  hyprctl activewindow -j 2>/dev/null \
    | sed -n 's/^[[:space:]]*"class": *"\([^"]*\)".*/\1/p' | head -n1
}

inject_preflight() {
  if ! command -v wtype >/dev/null 2>&1; then
    die "wtype is not installed (Arch: sudo pacman -S wtype; Debian: sudo apt install wtype)"
  fi

  # Optional window-class allowlist (fire-time check — see header note 1).
  # NOTE: Wayland classes are app_ids and can differ from X11 WM_CLASS
  # (kitty stays "kitty"; ghostty becomes "com.mitchellh.ghostty").
  local allowed="${I3_QUICKPHRASE_ALLOWED_CLASSES:-*}"
  if [[ "$allowed" != "*" ]]; then
    local active_class
    active_class="$(_qp_wl_active_class || true)"
    if [[ -z "$active_class" ]]; then
      die "I3_QUICKPHRASE_ALLOWED_CLASSES is set but the focused window's class could not be determined (is hyprctl available?)"
    fi
    if ! echo "$allowed" | tr ',' '\n' | grep -qFx "$active_class"; then
      die "focused window class '$active_class' not in allowlist '$allowed'"
    fi
  fi
}

inject_prepare() {
  # See header note 2: give the human time to get off the modifier.
  sleep "$QP_MOD_SETTLE"
}

# Non-space runs: stdin-fed (`wtype -`) so the byte-literal / no-argv-leak
# invariant holds per-run; -d 12 mirrors the X11 backend's 12 ms/char.
emit_text() {
  printf '%s' "$1" | wtype -d 12 -
}

# Spaces: discrete named-key press+release with no dwell — same reasoning
# as the X11 `xdotool key` path. Claude Code's held-space detector lives
# in the TUI, not in the display server, so the space dance survives the
# Wayland port unchanged.
emit_space() {
  wtype -k space
}

inject_doctor() {
  echo "Backend:     $INJECT_BACKEND (wtype)"
  if command -v wtype >/dev/null 2>&1; then
    echo "  [ok]      wtype: $(command -v wtype)"
  else
    echo "  [MISSING] wtype"
  fi
  if command -v hyprctl >/dev/null 2>&1; then
    echo "  [ok]      hyprctl: $(command -v hyprctl)"
  else
    echo "  [absent]  hyprctl (only needed for the class allowlist)"
  fi
  echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-(unset — wtype will not work)}"
  echo "Mod settle:  ${QP_MOD_SETTLE}s (I3_QUICKPHRASE_MOD_SETTLE)"
  local cls
  cls="$(_qp_wl_active_class || true)"
  echo "Active class: ${cls:-unknown}"
}
