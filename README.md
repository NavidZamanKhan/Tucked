# Tucked

Your Mac, at a glance.

Tucked is a native, ultra-lightweight menu-bar system monitor designed exclusively for Apple Silicon macOS. Built entirely with Swift, SwiftUI, and AppKit, Tucked delivers real-time system telemetry and process recovery without becoming the process that consumes resources.

## Core Principles

- Native-Only: Zero Electron, zero web views, zero JavaScript runtimes, and zero cross-platform wrappers.
- Zero Infrastructure: Zero backend, zero user accounts, zero cloud dependencies, zero telemetry, and zero analytics.
- Efficiency First: Tucked never polls shell binaries (no top, ps, vm_stat, or netstat). All metrics are sampled directly via Darwin Mach APIs, IOKit, and the Apple System Management Controller (SMC).

## Dual-State Engine

Tucked operates in two distinct modes to maintain near-zero CPU and energy impact:

- Passive Mode (Shelf Closed): Samples aggregate CPU utilization, RAM distribution, and 64-bit network throughput at ~1 Hz. Rolling telemetry buffers are updated in memory. Process enumeration, SMC thermals, Wi-Fi scanning, and latency probes are strictly off.
- Diagnostic Mode (Shelf Open): Asynchronously monitors CPU temperature, fan RPM, top 6 CPU processes, top 6 memory processes, network latency, and jitter. All diagnostic routines terminate immediately upon closing the shelf.

## Features

### Instrument-Grade Telemetry Graphs
- Canvas-rendered micro-area history charts with physical-pixel hairline top edges.
- Continuous piecewise-linear traces that preserve instantaneous spikes and drops without artificial bezier smoothing.
- Dual-channel bidirectional network graph dividing upload and download across an unbroken neutral center datum line.
- Dynamic stepped ceiling bandwidth scaling (128 KB/s to 100 MB/s) to accommodate high-speed bursts and quiet idle periods.

### Process Management and Recovery
- Simultaneous visibility of top 6 CPU and top 6 memory consumers.
- On-demand application icon caching.
- Hard process termination via SIGKILL (kill -9) for instant recovery from frozen or runaway applications.
- System process safety guards protecting critical OS components (WindowServer, loginwindow, Dock, Finder) with identity and UID revalidation prior to termination.

### Apple Silicon Hardware Telemetry
- Direct SMC sensor sampling for integer CPU core temperatures.
- Real-time fan speed reporting in whole RPM, with distinct representation for fanless hardware (such as MacBook Air).
- Read-only hardware safety: Tucked contains zero SMC write calls and performs no manual fan overrides.

### Network Intelligence
- Active interface detection (Wi-Fi, Ethernet) with RSSI signal strength, link speed, and SSID resolution.
- Low-overhead ICMP ping and jitter probes against public DNS infrastructure.
- Local IPv4 and public IP resolution.
- Cumulative session transfer counters with one-click reset.

### Single-Surface UI
- Continuous menu-bar status item opening a unified popover shelf.
- Dynamic island-style gliding spring animations for shelf presentation and dismissal.
- Full support for macOS light and dark appearances with manual theme overrides.
- In-shelf settings navigation with zero secondary windows.

## Requirements

- Platform: Apple Silicon Mac (M1, M2, M3, M4, M5 series and Pro/Max/Ultra variants)
- Operating System: macOS 14.0 (Sonoma) or later
- Architecture: arm64

## Installation

### Pre-Built Binary
Download the latest disk image (`Tucked.dmg`) from [GitHub Releases](https://github.com/NavidZamanKhan/Tucked/releases), open the disk image, and drag Tucked to your Applications folder.

### Building From Source

Prerequisites:
- Xcode 15 or later with Command Line Tools
- Swift 6.0 toolchain

Clone the repository:
```bash
git clone https://github.com/NavidZamanKhan/Tucked.git
cd Tucked
```

Build the release application bundle:
```bash
./scripts/build_app.sh
```

The compiled application will be generated at `build/Tucked.app`.

Run tests:
```bash
swift test
```

## Architecture Overview

```
Sources/Tucked/
|-- App/          # Application lifecycle, coordination, and delegates
|-- Shell/        # AppKit menu bar status item and popover controllers
|-- UI/           # SwiftUI shelf views, layout components, and micro-charts
|-- Monitoring/   # Unified coordinator, history ring buffers, and snapshots
|-- Sampling/     # Darwin Mach host statistics, memory, and network samplers
|-- Processes/    # libproc enumeration, process filtering, and termination
|-- Diagnostics/  # CoreWLAN Wi-Fi telemetry and network latency probes
|-- Thermal/      # Apple Silicon SMC sensor reader and fan monitoring
+-- Support/      # Machine information, binary formatters, and logging
```

## License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See the [LICENSE](LICENSE) file for details.
