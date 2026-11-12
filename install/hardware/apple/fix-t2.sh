# Detect T2 MacBook models using PCI IDs
# Vendor: 106b (Apple), Device IDs: 1801 or 1802 (T2 Security Chip)
if lspci -nn | grep "106b:180[12]" >/dev/null; then
  echo "Detected MacBook with T2 chip. Installing support items..."

  # T2 Macs run the stock linux-omarchy kernel with KaiT2en's T2 drivers built
  # by DKMS, instead of linux-t2. KaiT2en (https://github.com/kaiT2en/KaiT2en-Fedora)
  # targets stock kernels; its drivers replace the in-tree Apple ones:
  #   t2bce-stack-dkms     BCE bus: internal keyboard/trackpad (t2bce_vhci), audio
  #   t2smc-dkms           SMC: fans, charge limit, sensors (applesmc cannot reach
  #                        the T2 SMC on a stock kernel)
  #   t2sbs-dkms           battery percentage relative to full, not design capacity
  #   t2smp-dkms           offlines secondary CPUs around suspend; the early-resume
  #                        CPU bring-up otherwise takes seconds per CPU
  #   t2thunderbolt-dkms   Thunderbolt PM ordering (NHI before tunnelled ports)
  #   t2-precision-trackpad-dkms
  #                        the internal trackpad's multitouch and Force Touch: stock
  #                        kernels drive it as a plain mouse (no scroll, no tap)
  #   t2-wireless-dkms     the Broadcom Wi-Fi driver and btbcm/hci_uart/hci_bcm4377
  #                        with KaiT2en's Apple fixes: Wi-Fi resume (a firmware reload on wake),
  #                        and Bluetooth LE devices (stock btbcm drops these Macs'
  #                        LE advertisements, so LE keyboards and mice never show up)
  #   t2-fan-control       fan daemon on t2smc, replaces t2fanrd
  #   t2-smc-control       SMC app and t2-smc-gaugingd, which lifts a battery charge
  #                        limit for a full charge when the gauge needs one to
  #                        recalibrate, as macOS does
  #   t2bce-audio-ucm      ALSA UCM profiles for t2bce_audio
  #   t2-dsp               the speaker and microphone processing macOS applies to
  #                        each model's internal speakers, as PipeWire filter chains
  #                        (needs bankstown-lv2, from the same repo, and Arch's
  #                        lsp-plugins-lv2); a udev rule names the card t2-<model>
  #   t2-dkms-guard        aborts a linux-omarchy upgrade whose headers cannot build
  #                        these modules, so an update never removes the keyboard
  #                        driver needed at the disk unlock prompt
  # All DKMS packages build only for *-omarchy kernels. linux-t2 must not be
  # installed alongside: it carries its own t2bce for the same PCI device.
  #
  # The packages come from the signed [t2-arch-packages] repo
  # (install/hardware/pacman.sh). Its keyring goes first so the key is trusted
  # before anything from that repo is verified on later updates.
  #
  # The keyring package's post-install runs pacman-key --populate. During an
  # ISO install the installer is creating the target's keyring in the
  # background right now, and a second pacman-key on that keyring makes it fail
  # (its lsigns find no keys). There the scriptlet is skipped and the installer
  # populates t2-arch-packages once its keyring is done (omarchy-iso's
  # _populate_hardware_keyrings); everywhere else it runs as usual.
  if [[ ${OMARCHY_FIRST_INSTALL:-} == 1 ]]; then
    pacman -Q t2-arch-packages-keyring &>/dev/null ||
      pacman -S --noconfirm --needed --noscriptlet t2-arch-packages-keyring
  else
    omarchy-pkg-add t2-arch-packages-keyring
  fi
  omarchy-pkg-add \
    linux-omarchy-headers \
    t2bce-stack-dkms \
    t2smc-dkms \
    t2sbs-dkms \
    t2smp-dkms \
    t2thunderbolt-dkms \
    t2-precision-trackpad-dkms \
    t2-wireless-dkms \
    t2-fan-control \
    t2-smc-control \
    t2bce-audio-ucm \
    t2-dsp \
    t2-dkms-guard

  # apple-bcm-firmware-fetcher reads its firmware off an on-disk macOS volume —
  # Wi-Fi firmware for T2 Macs is only legally obtainable from there. A
  # single-boot install that wiped macOS has no such volume, so the fetch comes
  # up empty; those machines need the firmware supplied from a macOS copy or a
  # downloaded recovery image instead.
  #
  # It mounts that volume with the APFS driver, which linux-t2 builds in and
  # linux-omarchy does not: Arch's linux-apfs-rw-dkms (extra) provides it. DKMS builds only at
  # the end of a transaction, so the driver goes in first, on its own.
  omarchy-pkg-add linux-apfs-rw-dkms
  omarchy-pkg-add apple-bcm-firmware-fetcher

  # The fetcher's own post-install run happens inside the installer's chroot,
  # where modprobe works against the live ISO's kernel rather than the
  # installed linux-omarchy, so it usually comes up empty there. This unit
  # fetches on the installed system's boots until the fetcher records its files,
  # before networking starts, then brings the Wi-Fi card up on them.
  #
  # The card's driver has already probed by then (udev loads it at coldplug)
  # and failed for lack of firmware. Its pending firmware request holds the
  # module for a few more seconds, until it gives up and unbinds the card, so
  # the reload the fetcher runs right after copying can't remove it, ignores
  # that, and the first boot has no Wi-Fi until a reboot. t2-wifi-reload waits
  # that out and loads the driver again, which probes the card with its
  # firmware in place. It finds the card by its PCI class and the driver by
  # the card's modalias, removing whatever holds the driver (its _wcc helper)
  # first; it fails the unit only when the card still has no interface.
  mkdir -p /usr/local/sbin
  cat > /usr/local/sbin/t2-wifi-reload <<'EOF'
#!/bin/bash
# Written by Omarchy's installer (fix-t2.sh) for t2-wifi-firmware.service.
set -u

card=""
for dev in /sys/bus/pci/devices/*; do
  [[ $(<"$dev/class") == 0x0280* ]] && { card=$dev; break; }
done
[[ -n $card ]] || exit 0

up() { compgen -G "$card/net/*" >/dev/null; }
up && exit 0

driver=$(modprobe -R "$(<"$card/modalias")" 2>/dev/null | head -n1)
[[ -n $driver ]] || { echo "no driver for the Wi-Fi card at $card" >&2; exit 1; }

for _ in $(seq 30); do
  [[ -d /sys/module/$driver ]] || break
  for holder in /sys/module/"$driver"/holders/*; do
    [[ -e $holder ]] && modprobe -r "${holder##*/}" 2>/dev/null
  done
  modprobe -r "$driver" 2>/dev/null && break
  sleep 1
done
modprobe "$driver"

for _ in $(seq 15); do
  up && { echo "Wi-Fi card up on $driver"; exit 0; }
  sleep 1
done
echo "the Wi-Fi card at $card has no interface after reloading $driver" >&2
exit 1
EOF
  chmod 755 /usr/local/sbin/t2-wifi-reload

  cat > /etc/systemd/system/t2-wifi-firmware.service <<'EOF'
[Unit]
Description=Fetch the T2 Wi-Fi/Bluetooth firmware from the macOS volume
ConditionPathExists=!/var/lib/apple-bcm-firmware-fetcher/installed-files
After=local-fs.target
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/bin/apple-bcm-firmware-fetcher
ExecStartPost=/usr/local/sbin/t2-wifi-reload

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable t2-wifi-firmware.service

  # t2-fan-control ships /etc/t2-fancontrol/config.txt with a system chill
  # target of 80 C: upstream's 45 C (average of system and GPU sensors) pins the
  # fans of dGPU models such as MacBookPro16,1 at full speed.
  systemctl enable t2-fancontrol.service

  # With no charge limit set it never lifts anything; with one, it keeps the
  # battery gauge calibrated.
  systemctl enable t2-smc-gaugingd.service

  # The T2 keeps its internal devices on a USB bus t2bce_vhci exposes, and
  # beside the keyboard sits a CDC NCM network function, "Apple T2 Controller"
  # (05ac:8233): macOS's link to the T2 chip. cdc_ncm makes it an Ethernet
  # interface, and with no DHCP server on the T2, NetworkManager retries DHCP
  # on it every 45 s. Matched by USB ID, not by driver: USB tethering from a
  # phone is cdc_ncm too.
  mkdir -p /etc/udev/rules.d
  cat > /etc/udev/rules.d/90-t2-ibridge-unmanaged.rules <<'EOF'
# Written by Omarchy's installer (fix-t2.sh): NetworkManager leaves the T2's
# internal USB network link (Apple T2 Controller, 05ac:8233) alone. macOS talks
# to the T2 chip over it; Linux has no use for it, and with no DHCP server on
# the T2, NetworkManager would retry DHCP on it every 45 s.
SUBSYSTEM=="net", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="8233", ENV{NM_UNMANAGED}="1"
EOF

  mkdir -p /etc/modules-load.d
  {
    echo "t2bce_vhci"
    echo "hci_bcm4377"
  } > /etc/modules-load.d/t2.conf

  # t2bce_vhci is the virtual USB host controller the internal keyboard hangs
  # off; mkinitcpio pulls t2bce_core/t2bce_dma in via module dependencies. It
  # must be in the initramfs to type the disk encryption password.
  # t2_precision_trackpad goes first: it must be registered when t2bce_vhci
  # enumerates the trackpad, or hid-apple takes its mouse interface. It claims
  # only that interface, so hid-apple keeps the keyboard.
  # t2smc before t2sbs, so BAT0 already has charge_control_end_threshold when
  # udev and UPower first see it.
  mkdir -p /etc/mkinitcpio.conf.d
  echo "MODULES+=(t2_precision_trackpad t2bce_vhci usbhid hid_apple hid_generic xhci_pci xhci_hcd t2smc t2sbs)" > \
    /etc/mkinitcpio.conf.d/apple-t2.conf

  # pci=noaer: Apple firmware denies AER, and Linux using it anyway stalls
  # resume for seconds. pcie_ports=compat: no native PCIe port services on the
  # Thunderbolt bridges, which otherwise wait ~10 s each on resume (costs native
  # PCIe hotplug of Thunderbolt docks/eGPUs). pm_async=off is no longer needed:
  # the KaiT2en drivers resume in parallel. Together with t2smp the wake from
  # deep sleep takes ~1 s instead of ~16 s on a MacBookPro16,1.
  # These follow KaiT2en's current kernel arguments. #6559 replaced
  # pcie_ports=compat with pm_async=off based on KaiT2en's arguments of
  # August 2026, for linux-t2's t2bce; KaiT2en has since moved back.
  mkdir -p /etc/limine-entry-tool.d
  cat > /etc/limine-entry-tool.d/t2-mac.conf <<'EOF'
# Generated by Omarchy installer for T2 Mac support
KERNEL_CMDLINE[default]+=" intel_iommu=on iommu=pt mem_sleep_default=deep pci=noaer pcie_ports=compat"
EOF
fi
