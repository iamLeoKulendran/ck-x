#!/bin/bash

# Log startup
echo "Starting CKAD VNC service at $(date)"

echo "echo 'Use Ctrl + Shift + C for copying and Ctrl + Shift + V for pasting'" >> /home/candidate/.bashrc
echo "alias kubectl='echo \"kubectl not available here. Solve this question on the specified instance\"'" >> /home/candidate/.bashrc

configure_application_chrome() {
  mkdir -p /headless/.config/xfce4/terminal
  cat > /headless/.config/xfce4/terminal/terminalrc <<'EOF'
[Configuration]
MiscMenubarDefault=FALSE
MiscToolbarDefault=FALSE
EOF

  if [ -d /headless/.mozilla/firefox ]; then
    find /headless/.mozilla/firefox -maxdepth 1 -type d -name '*.default*' | while read -r profile; do
      python3 - "$profile/xulstore.json" <<'PY'
import json
import os
import sys

path = sys.argv[1]
data = {}
if os.path.exists(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except Exception:
        data = {}

browser = data.setdefault("chrome://browser/content/browser.xul", {})
browser["toolbar-menubar"] = {
    "autohide": "true",
    "inactive": "true"
}

with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, separators=(",", ":"))
PY
      cat > "$profile/user.js" <<'EOF'
user_pref("browser.fullscreen.autohide", true);
user_pref("browser.tabs.warnOnClose", false);
EOF
    done
  fi
}

ensure_window_buttons_plugin() {
  export DISPLAY="${DISPLAY:-:1}"
  local display_number="${DISPLAY#:}"

  for _ in $(seq 1 60); do
    if [ -S "/tmp/.X11-unix/X${display_number}" ] &&
      command -v xfconf-query >/dev/null 2>&1 &&
      command -v xfce4-panel >/dev/null 2>&1 &&
      pgrep -x xfce4-panel >/dev/null 2>&1; then
      local panel_plugins
      panel_plugins="$(xfconf-query -c xfce4-panel -lv 2>/dev/null || true)"

      if ! printf '%s\n' "$panel_plugins" | grep -Eq '/plugins/plugin-[0-9]+[[:space:]]+tasklist$'; then
        xfce4-panel --add=tasklist || true
      fi
      return 0
    fi
    sleep 1
  done

  return 0
}

configure_application_chrome >/tmp/ckx-application-chrome.log 2>&1 || true
(ensure_window_buttons_plugin >/tmp/ckx-window-buttons.log 2>&1 || true) &

# Run in the background - don't block the main container startup
python3 /tmp/agent.py &

exit 0 
