# Omarchy

Omarchy is a beautiful, fun & agentic Linux distribution by DHH.

Read more at [omarchy.org](https://omarchy.org).

## This fork: Omarchy for T2 Macs

This is Omarchy's installer with different support for Intel Macs that have
Apple's T2 chip. Upstream installs `linux-t2`, a patched kernel; this fork keeps
Omarchy's stock `linux-omarchy` and installs the T2 drivers and apps from
[KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora), packaged in
[t2-arch-packages](https://github.com/josemiguelo/t2-arch-packages): Touch ID,
the Touch Bar, Force Touch, AirDrop and Quick Share, hybrid graphics, True Tone,
the macOS speaker sound, a 1-second wake from sleep, and a T2 panel on the bar.

- **What it does and what works:** the
  [t2-arch-packages README](https://github.com/josemiguelo/t2-arch-packages#readme).
- **How to install:** build the ISO with the
  [omarchy-iso fork](https://github.com/josemiguelo/omarchy-iso/tree/t2-kait2en)
  from this branch (`t2-kait2en-stable`, Omarchy's stable release plus the T2
  changes); the steps are in that README.
- **The T2 changes:** `install/hardware/apple/fix-t2.sh` (packages, boot setup,
  services, firewall rules), `install/hardware/pacman.sh` (the package repo),
  `install/user/first-run/t2-omarchy.sh` (the T2 panel at first login).
  Everything else is upstream Omarchy, and after the install upstream's updates
  take over as on any Omarchy machine.

An independent, personal project; not endorsed by Omarchy or KaiT2en.

## The Omarchy Manual

The manual lives in [`manual/`](manual/), which is its authoritative source.

- [Welcome to Omarchy!](manual/01-welcome-to-omarchy.md)

**The Basics**

- [Getting Started](manual/02-getting-started.md)
- [Coming From Mac or Windows](manual/03-coming-from-mac-or-windows.md)
- [Navigation](manual/04-navigation.md)
- [The top bar](manual/05-the-top-bar.md)
- [Themes](manual/06-themes.md)
- [Hotkeys](manual/07-hotkeys.md)
- [Unified Clipboard & History](manual/08-unified-clipboard-history.md)
- [Reminders](manual/09-reminders.md)
- [Notices](manual/10-notices.md)
- [Text Extraction & Dictation](manual/11-text-extraction-dictation.md)
- [Screenshots & Recording](manual/12-screenshots-recording.md)
- [Toggles, idle & screensaver](manual/13-toggles-idle-screensaver.md)
- [Omarchy CLI](manual/14-omarchy-cli.md)

**The Applications**

- [Terminal](manual/15-terminal.md)
- [Neovim](manual/16-neovim.md)
- [AI](manual/17-ai.md)
- [Development Tools](manual/18-development-tools.md)
- [Shell Tools](manual/19-shell-tools.md)
- [Shell Functions](manual/20-shell-functions.md)
- [TUIs](manual/21-tuis.md)
- [GUIs](manual/22-guis.md)
- [Browsers](manual/23-browsers.md)
- [Commercial apps/services](manual/24-commercial-apps-services.md)
- [Web Apps](manual/25-web-apps.md)
- [Gaming](manual/26-gaming.md)
- [Filling out PDFs](manual/27-filling-out-pdfs.md)
- [Windows VM](manual/28-windows-vm.md)
- [Other Packages](manual/29-other-packages.md)

**Configuration**

- [Updates](manual/30-updates.md)
- [Dotfiles](manual/31-dotfiles.md)
- [Shell plugins](manual/32-shell-plugins.md)
- [Monitors](manual/33-monitors.md)
- [Keyboard, Mouse, Trackpad](manual/34-keyboard-mouse-trackpad.md)
- [Networking](manual/35-networking.md)
- [System sleep](manual/36-system-sleep.md)
- [Hardware authentication](manual/37-hardware-authentication.md)
- [Fonts](manual/38-fonts.md)
- [Backgrounds](manual/39-backgrounds.md)
- [Prompt](manual/40-prompt.md)
- [Branding](manual/41-branding.md)
- [Common tweaks](manual/42-common-tweaks.md)
- [Making your own theme](manual/43-making-your-own-theme.md)

**The Rest**

- [Mac support](manual/44-mac-support.md)
- [Troubleshooting](manual/45-troubleshooting.md)
- [FAQ](manual/46-faq.md)
- [System snapshots](manual/47-system-snapshots.md)
- [Security](manual/48-security.md)
- [Omarchy on...](manual/49-omarchy-on.md)
- [Dual Boot Install](manual/50-dual-boot-install.md)
- [Unattended Installs](manual/51-unattended-installs.md)

## License

Omarchy is released under the [MIT License](https://opensource.org/licenses/MIT).
