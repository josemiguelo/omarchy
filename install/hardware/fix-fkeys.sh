# Ensure that F-keys on Apple-like keyboards (such as Lofree Flow84) are always F-keys.
# Apple Silicon is left alone: the omarchy-mac package owns its keyboard mode.
# So are T2 Macs (Apple 106b:1801/1802): their internal keyboard has a Touch
# Bar, not an F-row, and hid_apple's default mode (3, which resolves to 4
# there) is the one that keeps Fn+arrows and Fn+Backspace; fnmode=2 would take
# those away. The PCI check avoids grep -q, which reads as no match under
# pipefail when lspci gets SIGPIPE.
conf="${OMARCHY_HID_APPLE_CONF:-/etc/modprobe.d/hid_apple.conf}"
if [[ ! -f $conf ]] && ! omarchy-hw-aarch64-apple && ! lspci -nn | grep "106b:180[12]" >/dev/null; then
  sudo mkdir -p "$(dirname "$conf")"
  echo "options hid_apple fnmode=2" | sudo tee "$conf" >/dev/null
fi
