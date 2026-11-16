# Hardware-specific pacman repository extensions that must survive the final
# pacman.conf restore.
if lspci -nn | grep "106b:180[12]" >/dev/null; then
  # KaiT2en T2 drivers and tools for linux-omarchy (install/hardware/apple/fix-t2.sh),
  # and apple-bcm-firmware-fetcher (the Wi-Fi/Bluetooth firmware), taken over
  # from the unsigned [arch-mact2]. Signed; the key comes from
  # t2-arch-packages-keyring, which fix-t2.sh installs and which
  # `pacman-key --populate` picks up.
  if ! grep -q '^\[t2-arch-packages\]' /etc/pacman.conf; then
    cat >> /etc/pacman.conf <<'EOF'

[t2-arch-packages]
Server = https://github.com/josemiguelo/t2-arch-packages/releases/download/repo
EOF
  fi
fi
