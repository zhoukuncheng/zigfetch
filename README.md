# zigfetch

A lightweight, cross-platform system information tool written in Zig, inspired by neofetch and fastfetch. Supports **Linux** and **Windows**.

## Features

- **Fast & Lightweight**: Minimal dependencies, written in Zig.
- **Cross-Platform**:
  - **Linux**: Efficiently gathers info via `/proc`, `/sys`, and standard utilities.
  - **Windows**: Native implementation using Win32 APIs, Registry, and WMI.
- **Comprehensive Info**: Displays OS, Kernel, Host, CPU, GPU, Memory, Disk, Network, Battery, and more.
- **Customizable**: Supports `--no-logo` and `--no-color`.

## Construction & Usage

### Building from source

Requirements: [Zig](https://ziglang.org/download/) 0.15+

```bash
# Build release executable
zig build -Doptimize=ReleaseSafe

# Located at:
# Linux:   ./zig-out/bin/zigfetch
# Windows: .\zig-out\bin\zigfetch.exe
```

### Running

```bash
# Run directly during development
zig build run

# Run with arguments
zig build run -- --no-logo
```

## Structure

- `src/main.zig`: Application entry point and argument parsing.
- `src/modules/`: Platform-specific information collectors.
- `src/render.zig`: ASCII art and text rendering logic.

## License

Apache-2.0
