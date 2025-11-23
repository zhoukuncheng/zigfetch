# zigfetch

zigfetch is a lightweight neofetch/fastfetch-style CLI written in Zig (Linux-first). It shows OS, kernel, host/user, CPU/GPU, memory/swap, disks, uptime, shell/terminal/locale, network (LAN/WAN, proxies, DNS), battery, and display info, with a distro-themed ASCII logo.

## Features
- Modular collectors: `/etc/os-release`, `uname`, `/proc/*`, DMI, env vars.
- Hardware: GPU (prefers `nvidia-smi`, falls back to `lspci`), display (`xrandr --listmonitors`), disks (`df -PT`), battery (`/sys/class/power_supply`).
- Network: LAN IP, WAN IP (via `curl`), proxy/tun/wg detection, DNS from `/etc/resolv.conf`.
- Rendering controls: `--no-color`, `--no-logo`; honors `NO_COLOR`.
- Minimal deps; tested with Zig 0.15.

## Usage
```bash
zig build
zig build run -- [--no-logo] [--no-color]
```

Requires access to `/etc/resolv.conf`, `/proc`, `/sys`, and best-effort helpers `ip`/`hostname -I`/`curl`; GPU info improves with `nvidia-smi`/`lspci`, display with `xrandr`, disk with `df`. Missing tools/values display as Unknown/Unavailable.

## Layout
- `src/main.zig` – entrypoint and CLI options
- `src/modules/` – collectors: os, kernel, host, user, cpu, gpu, memory, swap, disk, uptime, shell, terminal, locale, display, battery, network
- `src/render.zig` – logo-first rendering and aligned text
- `src/logo.zig` – distro ASCII logos
- `build.zig` – build script

## Development
```bash
zig fmt src
ZIG_GLOBAL_CACHE_DIR=.zig-global-cache zig build
```

## License
Apache-2.0, see [LICENSE](LICENSE).
