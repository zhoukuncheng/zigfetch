# zigfetch

zigfetch is a lightweight neofetch/fastfetch-style CLI written in Zig (Linux-first). It shows OS, kernel, host, CPU, memory, uptime, shell, terminal, and network details (LAN/WAN IP, proxies, DNS), with a distro-themed ASCII logo.

## Features
- Modular collectors: `/etc/os-release`, `uname`, `/proc/*`, DMI, env vars.
- Network visibility: LAN IP, WAN IP (via `curl`), proxy/tun/wg detection, DNS from `/etc/resolv.conf`.
- Rendering controls: `--no-color`, `--no-logo`; honors `NO_COLOR`.
- Minimal deps; tested with Zig 0.15.

## Usage
```bash
zig build
zig build run -- [--no-logo] [--no-color]
```

Requires access to `/etc/resolv.conf`, `/proc`, `/sys`, and best-effort helpers `ip`/`hostname -I`/`curl`. Missing tools/values display as Unknown/Unavailable.

## Layout
- `src/main.zig` – entrypoint and CLI options
- `src/modules/` – collectors: os, kernel, host, cpu, memory, uptime, shell, terminal, network
- `src/render.zig` – alignment and colors
- `src/logo.zig` – distro ASCII logos
- `build.zig` – build script

## Development
```bash
zig fmt src
ZIG_GLOBAL_CACHE_DIR=.zig-global-cache zig build
```

## License
Apache-2.0, see [LICENSE](LICENSE).
