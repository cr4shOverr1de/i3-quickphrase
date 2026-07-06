#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# i3-quickphrase X11 injection backend — sourced by bin/i3-quickphrase.
#
# Extracted verbatim from the v0.1.6 inline injection block (DESIGN.md
# pre-paid this factoring — it is why lib/ exists). xdotool, window-pinned,
# explicit modifier keyup. See SECURITY.md for the race-by-race rationale.
#
# Injector contract (implemented by every lib/inject-*.sh):
#   inject_preflight — backend deps + focus capture + class allowlist
#   inject_prepare   — pre-typing mitigation (here: modifier keyup)
#   emit_text <run>  — type one spaceless character run
#   emit_space       — emit one space as a discrete key event
#   inject_doctor    — backend-specific section of `doctor`

INJECT_BACKEND="x11"

# Captured by inject_preflight; every emit_* call targets this id.
QP_ACTIVE_ID=""

inject_preflight() {
  if ! command -v xdotool >/dev/null 2>&1; then
    die "xdotool is not installed"
  fi
  if [[ -z "${DISPLAY:-}" ]]; then
    die "DISPLAY is unset (no X server)"
  fi

  # Capture active window NOW (defeats focus drift between check and type)
  QP_ACTIVE_ID="$(xdotool getactivewindow 2>/dev/null || true)"
  [[ -n "$QP_ACTIVE_ID" ]] || die "no active window detected"

  # Optional window-class allowlist
  local allowed="${I3_QUICKPHRASE_ALLOWED_CLASSES:-*}"
  if [[ "$allowed" != "*" ]]; then
    if ! command -v xprop >/dev/null 2>&1; then
      die "I3_QUICKPHRASE_ALLOWED_CLASSES is set but xprop is not installed"
    fi
    # WM_CLASS is reported as: WM_CLASS(STRING) = "instance", "class"
    # We grab the second quoted string (the class).
    local active_class
    active_class="$(xprop -id "$QP_ACTIVE_ID" WM_CLASS 2>/dev/null \
                    | sed -n 's/.*"\([^"]*\)"$/\1/p')"
    if [[ -z "$active_class" ]]; then
      die "could not determine active window class"
    fi
    if ! echo "$allowed" | tr ',' '\n' | grep -qFx "$active_class"; then
      die "focused window class '$active_class' not in allowlist '$allowed'"
    fi
  fi
}

inject_prepare() {
  # Defeat the held-modifier race: explicitly release any modifier keys
  # before typing. This is more reliable than xdotool's --clearmodifiers,
  # which has a known "restore" bug (xdotool#43) where it re-presses
  # modifiers at the end of typing — leaving them stuck if the user has
  # already released them physically.
  xdotool keyup Alt_L Alt_R Control_L Control_R Shift_L Shift_R Super_L Super_R 2>/dev/null || true

  # Tiny propagation delay so the synthetic keyup events land before
  # xdotool starts pumping characters into X11's event queue.
  sleep 0.03
}

# Non-space runs: `xdotool type` at 12 ms/char, stdin-fed (`--file -`) so
# the byte-literal / no-argv-leak invariant holds per-run.
emit_text() {
  printf '%s' "$1" | xdotool type --delay 12 --window "$QP_ACTIVE_ID" --file -
}

# Spaces: `xdotool key --delay 0` emits KeyPress+KeyRelease back-to-back
# via a single XTEST call pair — sub-millisecond dwell, below Claude
# Code's voice-mode detection window.
emit_space() {
  xdotool key --delay 0 --window "$QP_ACTIVE_ID" space
}

inject_doctor() {
  local cmd
  echo "Backend:     $INJECT_BACKEND (xdotool)"
  for cmd in xdotool xprop i3-msg; do
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "  [ok]      $cmd: $(command -v "$cmd")"
    else
      echo "  [MISSING] $cmd"
    fi
  done
  if [[ -n "${DISPLAY:-}" ]]; then
    echo "DISPLAY:     $DISPLAY"
  else
    echo "DISPLAY:     (unset — xdotool will not work)"
  fi
  if command -v xdotool >/dev/null 2>&1; then
    local id
    id="$(xdotool getactivewindow 2>/dev/null || true)"
    if [[ -n "$id" ]]; then
      echo "Active id:   $id"
      if command -v xprop >/dev/null 2>&1; then
        local wmclass
        wmclass="$(xprop -id "$id" WM_CLASS 2>/dev/null || true)"
        echo "Active class: ${wmclass:-unknown}"
      fi
    fi
  fi
}
