#!/bin/bash
sudo -u sreeram dbus-run-session bash -c "
    dconf write /org/gnome/desktop/wm/preferences/button-layout \"'appmenu:minimize,maximize,close'\"
    sleep 1
"
