#!/bin/bash

# T2 Macs: the Sidecar panel (t2-sidecar's Omarchy plugin, josemiguelo.sidecar)
# on the bar. Omarchy loads third-party plugins only from the user's
# ~/.config/omarchy/plugins, so t2-sidecar links its packaged copy there and
# places the widget, which needs the shell running: hence first run, not the
# image. Elsewhere t2-sidecar isn't installed and this does nothing.

set -e

if omarchy-pkg-present t2-sidecar; then
  t2-sidecar setup-plugin
fi
