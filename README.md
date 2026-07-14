# OpenAVSwitch

An open, modular AV processing mainframe in the spirit of the Analog Way
Aquilon / Barco E3 class of live-event video processors: multiple
simultaneous inputs, multi-layer real-time compositing/scaling, and seamless
switching, built on commodity FPGA SoCs instead of closed proprietary
hardware.

## Disclaimers

**Relationship to MiSTer FPGA:** this project is *inspired by* the
[MiSTer FPGA project](https://github.com/MiSTer-devel) — its open,
community-driven, reproducible approach to FPGA hardware — but it is
**not** a MiSTer fork, derivative, or dependent in any way. No MiSTer
code, cores, or framework are used here. MiSTer's DE10-Nano/Cyclone V
target has no HDMI input path and essentially no spare logic or DDR3
bandwidth once its HPS Linux bridge is accounted for, so it's the wrong
technical base for this project regardless; everything in `rtl/` and
`docs/` here is original, targeting Xilinx/AMD Zynq UltraScale+ instead.
See [docs/architecture.md](docs/architecture.md) for the full reasoning.

**AI involvement:** the RTL, testbenches, and documentation in this
repository are being written collaboratively with AI assistance (Claude
Code), directed and reviewed by a human author. Treat this as you would
any early-stage hobby/community hardware project: nothing here has been
through professional design review, third-party audit, or real-hardware
validation yet (see [Status](#status) below). Read the design docs and
RTL critically, especially before relying on this for anything beyond
simulation.

![Phase 1 signal path: 4x asynchronous HDMI inputs through per-channel capture and scaling into a frame-boundary-latched seamless switch, out to 1x HDMI output](docs/diagrams/phase1-blueprint.svg)

## Vision

A chassis-style system: a host/control card plus a bus of pluggable I/O
daughtercards (HDMI, SDI, DisplayPort, and eventually third-party capture
cards like Blackmagic DeckLink), all feeding a real-time layer
compositor/scaler/switcher core, scaling up from a single input/output pair
to many simultaneous 4K/8K inputs across multiple layers.

## Status

Pre-hardware. The Phase 1 **logic/simulation track** is done and passing:
a double-buffered continuous-capture pipeline, a per-channel
nearest-neighbor scaler, and a frame-boundary-latched seamless switch,
all proven in Icarus Verilog simulation across 4 asynchronous,
mismatched-resolution simulated sources — see [sim/README.md](sim/README.md).
Nothing has been synthesized or run on real silicon yet; no board has
been purchased. See [docs/](docs/) for design docs and
[docs/roadmap.md](docs/roadmap.md) for the phased plan.

## Phase 1 goal

A single board (no card cage yet): 4x HDMI input, 4K-capable, seamlessly
switched/scaled to 1x HDMI output. Proves the capture -> frame buffer ->
scale -> crossbar -> output pipeline before any of the modularity
(daughtercards, multi-layer compositing, third-party card support) is
layered on. Details in [docs/phase1-plan.md](docs/phase1-plan.md) and
[docs/roadmap.md](docs/roadmap.md).

## Repo layout

- `docs/` — architecture, specs, roadmap
- `hardware/` — board/daughtercard designs (schematics, connector specs)
- `rtl/` — FPGA HDL: capture, scaler, compositor, output, common/shared
- `sim/` — testbenches and simulation
- `host-sw/` — Linux-side control plane and third-party card drivers (e.g. DeckLink)
- `tools/` — build scripts, utilities
