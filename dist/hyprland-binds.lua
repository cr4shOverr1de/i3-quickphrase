-- i3-quickphrase Hyprland bindings — Lua config parser flavor.
-- (Running classic hyprland.conf syntax? Use dist/hyprland.conf instead.)
--
-- release = true mirrors i3's `bindsym --release`: the bind fires on
-- key-up. This is MANDATORY on Wayland — the script cannot keyup a
-- physically held modifier the way xdotool could on X11 (see SECURITY.md
-- "Wayland differences").
--
-- Add a phrase: drop phrases/<name>.txt, copy one line below, change the
-- key and phrase name, then `hyprctl reload`.

hl.bind("ALT + M",      hl.dsp.exec_cmd("~/.local/bin/i3-quickphrase comprehensive"), { release = true })
hl.bind("ALT + period", hl.dsp.exec_cmd("~/.local/bin/i3-quickphrase clarify"),       { release = true })
