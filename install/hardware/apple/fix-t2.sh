# Detect T2 MacBook models using PCI IDs
# Vendor: 106b (Apple), Device IDs: 1801 or 1802 (T2 Security Chip)
if lspci -nn | grep "106b:180[12]" >/dev/null; then
  echo "Detected MacBook with T2 chip. Installing support items..."

  # T2 Macs run the stock linux-omarchy kernel with KaiT2en's T2 drivers built
  # by DKMS, instead of linux-t2. KaiT2en (https://github.com/kaiT2en/KaiT2en-Fedora)
  # targets stock kernels; its drivers replace the in-tree Apple ones. They
  # come as one meta-package, t2-mac (and t2-mac-hybrid on dual-GPU models),
  # so a T2 package added later reaches installed Macs with the next update;
  # what t2-mac pulls in:
  #   apple-t2-bridge-dkms the T2 bridge: internal keyboard/trackpad, Touch Bar,
  #                        camera (apple_t2_vhci_hcd), audio (snd_apple_t2), the
  #                        video encoders (t2_ave, t2_sidecar)
  #   t2smc-dkms           SMC: fans, charge limit, sensors (applesmc cannot reach
  #                        the T2 SMC on a stock kernel)
  #   t2sbs-dkms           battery percentage relative to full, not design capacity
  #   t2smp-dkms           offlines secondary CPUs around suspend; the early-resume
  #                        CPU bring-up otherwise takes seconds per CPU
  #   t2-thunderbolt-dkms  the thunderbolt driver with Apple RTD3: the idle Titan
  #                        Ridge controllers power off (deeper package C-states),
  #                        plus the PM ordering (NHI before tunnelled ports)
  #   t2-precision-trackpad-dkms
  #                        the internal trackpad's multitouch and Force Touch: stock
  #                        kernels drive it as a plain mouse (no scroll, no tap)
  #   t2-wireless-dkms     the Broadcom Wi-Fi driver and btbcm/hci_uart/hci_bcm4377
  #                        with KaiT2en's Apple fixes: Wi-Fi resume (a firmware reload on wake),
  #                        and Bluetooth LE devices (stock btbcm drops these Macs'
  #                        LE advertisements, so LE keyboards and mice never show up)
  #   t2-fan-control       fan daemon on t2smc, replaces t2fanrd (the T2 panel's
  #                        Fans tab)
  #   t2-smc-control       the T2 panel's Battery tab and t2-smc-gaugingd, which
  #                        lifts a battery charge
  #                        limit for a full charge when the gauge needs one to
  #                        recalibrate, as macOS does
  #   apple-t2-audio-ucm   ALSA UCM profiles for snd_apple_t2
  #   t2-trackpad-actuator-dkms, t2-force-click
  #                        the trackpad's Taptic Engine (a haptic click on force
  #                        click; a udev rule hands it its interface, which
  #                        hid-apple binds first) and the daemon for click
  #                        pressure and a force click action (the T2 panel's
  #                        Trackpad tab)
  #   t2-dsp               the speaker and microphone processing macOS applies to
  #                        each model's internal speakers, as PipeWire filter chains
  #                        (needs bankstown-lv2, from the same repo, and Arch's
  #                        lsp-plugins-lv2); a udev rule names the card t2-<model>
  #   t2-dkms-guard        aborts a linux-omarchy upgrade whose headers cannot build
  #                        these modules, so an update never removes the keyboard
  #                        driver needed at the disk unlock prompt
  #   t2-touchid           Touch ID through fprintd: the T2's Secure Enclave matches
  #                        the finger (enrolled in macOS) and the daemon hands fprintd
  #                        the verdict through libfprint's virtual storage driver. A
  #                        udev rule brings the T2's internal link up as it appears.
  #                        Omarchy's fingerprint setup turns it on, as on any laptop
  #                        with a reader, installing libfprint-git and fprintd
  #                        (offline from the ISO's package list).
  #   t2-touchbar-dkms, t2-touchbar
  #                        the internal keyboard on t2hid (a hid-apple fork with
  #                        the same options, which leaves the trackpad's mouse and
  #                        actuator interfaces alone), the Touch Bar on
  #                        t2touchbar_kbd/_bl and t2bdrm (its screen as a DRM
  #                        device on a private seat), and the daemon drawing the
  #                        bar: dark until touched or Fn, media and F-key layers,
  #                        swipes for volume and brightness, haptics, the Touch ID
  #                        prompt
  #   t2-kbd-backlight     fades the keyboard backlight out after 30 s without
  #                        input and back on the next (through UPower), and puts
  #                        it back before suspend so the keyboard resumes lit
  #   t2-drop, t2-airshare AirDrop with Apple devices (over AWDL, from the Wi-Fi
  #                        patches above) and Quick Share with Android phones:
  #                        sending and a receiver from the T2 panel's AirShare
  #                        tab, whose "visible" switch starts the receiver and
  #                        makes the Mac discoverable over Bluetooth, so it stays
  #                        off until the owner turns it on
  #   t2-truetone          the ambient light sensor at work: the panel's white
  #                        follows the room's light (True Tone, a gamma table
  #                        under the night light's colour matrix) and its
  #                        brightness follows macOS's curve, learning from the
  #                        brightness keys
  #   t2-acpi-fix          builds an override of the firmware's CPU table from
  #                        the Mac's own tables, so it stops loading sub-tables
  #                        twice (AE_ALREADY_EXISTS at every boot, CPU _OSC/_PDC
  #                        aborted); run once on the first boot, below
  #   t2-kernel-args       the kernel arguments, kept (see below)
  #   t2-journal           the T2's own logs (bridgeOS) merged with the Linux
  #                        journal: `t2journal -b`, for debugging the T2 side
  #   t2-ave               the T2's HEVC and Sidecar video encoders as V4L2
  #                        devices (ffmpeg's hevc_v4l2m2m/h264_v4l2m2m) through a
  #                        root daemon (t2-ave.service, enabled below, with
  #                        t2-ave-suspend.service closing its sessions around sleep)
  #   t2-sidecar, sunshine-t2
  #                        a phone or tablet as a second screen (or a view of
  #                        this one) through Moonlight, encoded by the T2's
  #                        Sidecar encoder: `t2-sidecar on|mirror|off`; needs
  #                        t2-ave on; sunshine-t2 is Sunshine with the V4L2
  #                        encoder (in place of Omarchy's sunshine)
  #   t2-omarchy-plugins   the T2 panel on the bar: one icon, a tab per feature
  #                        above (Battery, Fans, Graphics, Trackpad, Ambient
  #                        Light, AirShare, Sidecar); put in place at first login
  #                        (install/user/first-run/t2-omarchy.sh)
  #   apple-bcm-firmware-fetcher, linux-apfs-rw-dkms
  #                        the Wi-Fi/Bluetooth firmware from macOS (below)
  # Dual-GPU models only (MacBookPro15,1/15,3/16,1/16,4), for hybrid graphics,
  # t2-mac-hybrid:
  #   t2gmux-dkms, t2-amdgpu-dkms, t2-i915-dkms
  #                        KaiT2en's gmux driver (in place of apple_gmux),
  #                        amdgpu with its GMUX runtime PM (the dGPU off in
  #                        D3cold until an app asks for it) and i915 for the
  #                        panel on the iGPU (with a fix that power cycles the
  #                        panel after a wake, which stays dark otherwise)
  #   t2-boot-gpu          sets and keeps Apple's boot GPU variable
  #                        (`t2-boot-gpu integrated` is hybrid mode); Hyprland
  #                        renders on the panel's GPU (a uwsm env snippet)
  #   t2-gmux-backlight    the panel's brightness kept across suspend, blanks and
  #                        logins (the gmux resets it as the panel powers up)
  #                        These only make hybrid mode possible: the boot GPU is
  #                        left as it is (the dGPU); the T2 panel's Graphics tab
  #                        switches it (the owner's setup picks Hybrid once)
  # All DKMS packages build only for *-omarchy kernels. linux-t2 must not be
  # installed alongside: it carries its own bridge driver for the same PCI device.
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
  # The APFS driver first, in a transaction of its own: DKMS builds at the end
  # of a transaction, and apple-bcm-firmware-fetcher (in t2-mac) mounts the
  # macOS volume with it (below).
  omarchy-pkg-add linux-apfs-rw-dkms
  omarchy-pkg-add t2-mac

  # Hybrid graphics needs both GPUs (by PCI class from sysfs: config space reads
  # would wake a dGPU in D3cold). The drivers build now, offline; the boot GPU
  # stays the dGPU until `t2-boot-gpu integrated`.
  t2_igpu=0 t2_dgpu=0
  for t2_dev in /sys/bus/pci/devices/*; do
    [[ $(<"$t2_dev/class") == 0x0300* ]] || continue
    case $(<"$t2_dev/vendor") in
    0x8086) t2_igpu=1 ;;
    0x1002) t2_dgpu=1 ;;
    esac
  done
  if (( t2_igpu && t2_dgpu )); then
    omarchy-pkg-add t2-mac-hybrid
    # Puts the boot GPU chosen in the T2 panel's Graphics tab back at every
    # boot (macOS resets it at each of its own); with nothing chosen it does
    # nothing.
    systemctl enable t2-boot-gpu.service
  fi
  unset t2_igpu t2_dgpu t2_dev

  # apple-bcm-firmware-fetcher reads its firmware off an on-disk macOS volume —
  # Wi-Fi firmware for T2 Macs is only legally obtainable from there. A
  # single-boot install that wiped macOS has no such volume, so the fetch comes
  # up empty; those machines need the firmware supplied from a macOS copy or a
  # downloaded recovery image instead.
  #
  # It mounts that volume with the APFS driver, which linux-t2 builds in and
  # linux-omarchy does not: Arch's linux-apfs-rw-dkms (extra) provides it,
  # installed on its own before t2-mac (above).

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

  # The ACPI override is built from the running Mac's tables and only for an
  # error that boot's kernel log shows, so it can't be made in the installer's
  # chroot. This unit makes it on the first boot, before the login screen:
  # t2-acpi-fix writes /etc/initcpio/acpi_override/*.aml and the mkinitcpio
  # drop-in that adds the acpi_override hook, the boot image is rebuilt with
  # it, and it applies from the next boot. It runs once (a failure retries on
  # the next boot); after a firmware update, run `t2-acpi-fix` again by hand.
  # Undo: remove the .aml and /etc/mkinitcpio.conf.d/zz-t2-acpi-fix.conf, then
  # `limine-mkinitcpio`.
  cat > /etc/systemd/system/t2-acpi-fix.service <<'EOF'
[Unit]
Description=Build the T2 ACPI table override from this Mac's tables
ConditionPathExists=!/var/lib/t2-acpi-fix/done
After=local-fs.target systemd-journald.service
Before=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/bin/t2-acpi-fix
ExecStartPost=/bin/sh -c 'if [ -e /etc/mkinitcpio.conf.d/zz-t2-acpi-fix.conf ]; then limine-mkinitcpio; fi'
ExecStartPost=/bin/sh -c 'mkdir -p /var/lib/t2-acpi-fix && touch /var/lib/t2-acpi-fix/done'
TimeoutStartSec=10min

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable t2-acpi-fix.service

  # t2-fan-control ships /etc/t2-fancontrol/config.txt with a system chill
  # target of 80 C: upstream's 45 C (average of system and GPU sensors) pins the
  # fans of dGPU models such as MacBookPro16,1 at full speed.
  systemctl enable t2-fancontrol.service

  # With no charge limit set it never lifts anything; with one, it keeps the
  # battery gauge calibrated.
  systemctl enable t2-smc-gaugingd.service

  # Writes the charge limit in /etc/t2-charge-limit.conf (LIMIT=<percent>) to
  # the SMC at every boot, since macOS may change it; with no such file it
  # doesn't run.
  systemctl enable t2-charge-limit.service

  # Applies the saved click pressure and force click settings at boot.
  systemctl enable t2-force-click.service

  # Touch ID: the daemon keeps a session with the T2's Secure Enclave and tells
  # Omarchy's fingerprint detection the reader is ready (the package's
  # /usr/share/omarchy-platform/fingerprint-readers), so the fingerprint setup
  # and its first-run invitation find it. Nothing is bound or in PAM until that
  # setup runs: its enroll step binds the finger enrolled in macOS.
  systemctl enable t2-touchid.service

  # The T2's internal USB network link ("Apple T2 Controller", 05ac:8233,
  # macOS's line to the T2 chip, a CDC NCM function beside the keyboard) is
  # kept away from NetworkManager by t2-touchid's own udev rule: there's no
  # DHCP server on the T2, and NetworkManager would retry DHCP on it every 45 s.

  mkdir -p /etc/modules-load.d
  {
    echo "apple_t2_vhci_hcd"
    echo "hci_bcm4377"
  } > /etc/modules-load.d/t2.conf

  # apple_t2_vhci_hcd is the virtual USB host controller the internal keyboard
  # hangs off, on an auxiliary device of apple_t2_bridge (listed too, as
  # KaiT2en's initramfs does). Both must be in the initramfs to type the disk
  # encryption password. (Before 2026-11-19, t2bce_vhci; apple-t2-bridge-dkms's
  # install script renames it on installed Macs.)
  # t2_precision_trackpad goes first: it must be registered when apple_t2_vhci_hcd
  # enumerates the trackpad, to take its mouse interface. t2hid, the keyboard
  # driver, must be here for the password prompt; hid-apple is blacklisted
  # below, and modconf carries that blacklist into the image.
  # t2smc before t2sbs, so BAT0 already has charge_control_end_threshold when
  # udev and UPower first see it.
  mkdir -p /etc/mkinitcpio.conf.d
  echo "MODULES+=(t2_precision_trackpad apple_t2_bridge apple_t2_vhci_hcd usbhid t2hid hid_generic xhci_pci xhci_hcd t2smc t2sbs)" > \
    /etc/mkinitcpio.conf.d/apple-t2.conf

  # The keyboard and Touch Bar on t2-touchbar-dkms. The package installs its
  # drivers inert (/usr/lib/modprobe.d/t2-touchbar.conf blacklists them, since
  # they claim the same devices as hid-apple and the in-kernel Touch Bar
  # drivers); this file of the same name takes its place and blacklists those
  # instead. hid_apple's options don't reach t2hid: T2 keyboards keep the
  # default fnmode (3, which keeps Fn+arrows and Fn+Backspace), as
  # fix-fkeys.sh leaves them.
  mkdir -p /etc/modprobe.d
  cat > /etc/modprobe.d/t2-touchbar.conf <<'EOF'
# Omarchy (fix-t2.sh): the internal keyboard and Touch Bar on t2hid,
# t2touchbar_kbd/_bl and t2bdrm (t2-touchbar-dkms), in place of the in-kernel
# drivers. Takes the place of the package's file of the same name in
# /usr/lib/modprobe.d, which keeps them off.
blacklist hid_apple
blacklist hid_appletb_kbd
blacklist hid_appletb_bl
blacklist appletbdrm
EOF

  # The Touch Bar daemon runs in the user's session: its group opens the bar's
  # screen and digitizer, the keyboard's event node (for Fn), uinput and the
  # bar's light. A user created at first boot gets it from the provisioning
  # record. Enabled globally, the user service switches the bar from Apple's
  # firmware row to its screen when the graphical session starts, and back
  # when it ends (t2-touchbar 0.1.0.r40.b0acfa7-1); the console and the unlock prompt
  # keep the firmware row with Esc.
  if [[ -n ${OMARCHY_INSTALL_USER:-} ]]; then
    usermod -aG t2-touchbar "$OMARCHY_INSTALL_USER"
  else
    mkdir -p /var/lib/omarchy/provisioning
    grep -qx t2-touchbar /var/lib/omarchy/provisioning/groups 2>/dev/null ||
      echo t2-touchbar >>/var/lib/omarchy/provisioning/groups
  fi
  systemctl --global enable t2-touchbar.service

  # Fades the keyboard backlight while idle, the login screen included.
  systemctl enable t2-kbd-backlight.service

  # The T2's video encoders (HEVC, and the Sidecar encoder t2-sidecar streams
  # through), with their sessions closed around sleep.
  systemctl enable t2-ave.service t2-ave-suspend.service

  # True Tone and automatic brightness, a user service in every graphical
  # session; its settings are ~/.config/t2-truetone/config.toml.
  systemctl --global enable t2-truetone.service

  # config/firewall.sh ran before this step and already set ufw's ENABLED=yes
  # for the installed system: with it on, `ufw allow` also loads each rule into
  # the running firewall, which in the installer is the live system's and
  # fails ("ERROR: problem running"), stopping the install. Switch it off while
  # the rules are added, so they're only saved, and put it back after: they
  # load at the first boot with the rest.
  t2_ufw_enabled=$(sed -n 's/^ENABLED=//p' /etc/ufw/ufw.conf)
  sed -i 's/^ENABLED=.*/ENABLED=no/' /etc/ufw/ufw.conf

  # The firewall lets transfers in (install/config/firewall.sh denies incoming):
  # Quick Share on its port (fixed by the t2-airshare package), the hotspot it
  # opens for a transfer that started over Bluetooth (the phone's DHCP, DNS and
  # the transfer), and AirDrop on the AWDL interface. The comments are what the
  # owner's setup checks for.
  ufw allow 47901/tcp comment 't2-airshare quick share'
  ufw allow in on t2qs0 comment 't2-airshare hotspot'
  ufw allow in on awdl0 to any port 8770 proto tcp comment 't2-drop airdrop'

  # t2-sidecar's Sunshine, for Moonlight, from the private networks only:
  # Omarchy's own ports and networks (omarchy-install-service-sunshine), so
  # omarchy-remove-service-sunshine closes these too. TCP: pairing, app list,
  # RTSP; UDP: mDNS (Moonlight finds the Mac by itself), video, control, audio.
  for t2_net in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    for t2_port in 47984 47989 48010; do
      ufw allow in proto tcp from "$t2_net" to any port "$t2_port" comment 't2-sidecar'
    done
    for t2_port in 5353 47998 47999 48000 48002 48010; do
      ufw allow in proto udp from "$t2_net" to any port "$t2_port" comment 't2-sidecar'
    done
  done
  unset t2_net t2_port

  sed -i "s/^ENABLED=.*/ENABLED=${t2_ufw_enabled:-yes}/" /etc/ufw/ufw.conf
  unset t2_ufw_enabled

  # The kernel arguments (/etc/limine-entry-tool.d/t2-mac.conf) are
  # t2-kernel-args': pci=noaer and pcie_ports=compat (with t2smp, a ~1 s wake
  # from deep sleep instead of ~16 s), forced PCIe ASPM (deeper package
  # C-states; not on iMacs) and the rest; its header says why. Written here
  # for the installer's own boot image build; afterwards its path unit and
  # boot service write them back whenever something else rewrites the file
  # (an Omarchy migration once swapped pcie_ports=compat for pm_async=off).
  t2-kernel-args --write
fi
