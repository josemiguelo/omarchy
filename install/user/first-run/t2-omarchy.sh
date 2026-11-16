#!/bin/bash

# T2 Macs: the T2 packages' Omarchy bar plugins (Ambient Light, AirShare,
# Sidecar, ...) and menu entries for this user. Omarchy loads third-party
# plugins and menu extensions only from ~/.config/omarchy, so
# t2-omarchy-setup (t2-omarchy-plugins) links the packaged plugins there,
# places them on the bar and writes the menu entries, which needs the shell
# running: hence first run, not the image. Elsewhere it isn't installed and
# this does nothing.

set -e

if omarchy-pkg-present t2-omarchy-plugins; then
  t2-omarchy-setup
fi
