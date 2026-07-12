# av-mainframe

An open, modular AV processing mainframe in the spirit of the Analog Way
Aquilon / Barco E3 class of live-event video processors: multiple
simultaneous inputs, multi-layer real-time compositing/scaling, and seamless
switching, built on commodity FPGA SoCs instead of closed proprietary
hardware.

This project takes inspiration from [MiSTer FPGA](https://github.com/MiSTer-devel)
(open, community-driven, reproducible FPGA hardware) but is **not** a MiSTer
fork or derivative — MiSTer's DE10-Nano/Cyclone V target has no HDMI input
path and essentially no spare logic or DDR3 bandwidth once the HPS Linux
bridge is accounted for. It's the wrong base for this project. See
[docs/architecture.md](docs/architecture.md) for why this is being built on
Xilinx/AMD Zynq UltraScale+ instead.

## Vision

A chassis-style system: a host/control card plus a bus of pluggable I/O
daughtercards (HDMI, SDI, DisplayPort, and eventually third-party capture
cards like Blackmagic DeckLink), all feeding a real-time layer
compositor/scaler/switcher core, scaling up from a single input/output pair
to many simultaneous 4K/8K inputs across multiple layers.

## Status

Pre-hardware, architecture/spec phase. Nothing has been built or synthesized
yet — see [docs/](docs/) for the current design docs and
[docs/roadmap.md](docs/roadmap.md) for the phased plan.

## Phase 1 goal

A single board (no card cage yet): 4x HDMI input, 4K-capable, seamlessly
switched/scaled to 1x HDMI output. Proves the capture -> frame buffer ->
scale -> crossbar -> output pipeline before any of the modularity
(daughtercards, multi-layer compositing, third-party card support) is
layered on. Details in [docs/roadmap.md](docs/roadmap.md).

## Repo layout

- `docs/` — architecture, specs, roadmap
- `hardware/` — board/daughtercard designs (schematics, connector specs)
- `rtl/` — FPGA HDL: capture, scaler, compositor, output, common/shared
- `sim/` — testbenches and simulation
- `host-sw/` — Linux-side control plane and third-party card drivers (e.g. DeckLink)
- `tools/` — build scripts, utilities
