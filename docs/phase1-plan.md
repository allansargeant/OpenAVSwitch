# Phase 1 plan — 4-in / 1-out HDMI seamless switcher

Status: in progress. This pins down concrete choices so RTL work has a
fixed reference instead of re-deciding things per module.

## Target hardware (real board, later)

Researched and recommended (not yet purchased) in
[hardware-selection.md](hardware-selection.md): **ALINX Z7-P**
(XCZU7EV Zynq UltraScale+, same chip family as originally proposed,
~2.5x cheaper than AMD's own ZCU106) + HDMI-capable FMC card(s) for the
4 inputs and 1 output. Key refinement over the original proposal: GTH
transceiver budget, not compute/DDR bandwidth, turns out to be the real
constraint on reaching 4 simultaneous HDMI inputs, so the real design
likely mixes a couple of direct-GTH ports with a couple of chip-based
(MIPI-CSI-2) receiver ports rather than 4 identical direct-GTH ports —
see hardware-selection.md for why. Still not purchased — nothing in the
RTL below depends on this choice, deliberately, so hardware selection
doesn't block logic-level work.

## What Phase 1 actually proves

The core architectural claim in architecture.md: every input is
continuously captured into its own frame buffer regardless of whether
it's on air, and switching is just the output stage choosing which
buffer to read at its own frame boundary — never touching or resetting
an input's capture path. This is what makes it "seamless" (no black
frame, no re-sync) instead of a plain (glitchy) input switch.

Phase 1 is split into two tracks that can proceed independently:

1. **Logic/simulation track (starting now):** technology-independent
   SystemVerilog for the capture->buffer->crossbar->output pipeline,
   proven in simulation (Icarus Verilog) with a synthetic test pattern
   and a small synthetic resolution — no HDMI PHY, no Xilinx primitives,
   no real board needed. Goal: prove the double-buffer CDC handoff and
   frame-boundary-only switching are actually glitch-free under
   asynchronous clocks, before spending effort on real HDMI receiver
   integration.
2. **Hardware/bring-up track (later, once board is confirmed):** real
   HDMI receiver front-end (chip/IP TBD), real DDR4-backed frame buffers
   via the Zynq's memory controller, real 4K timing, Vivado build.

## Module list (logic/simulation track)

- `rtl/common/sync_2ff.sv` — generic multi-bit 2-flop CDC synchronizer.
- `rtl/capture/frame_buffer_channel.sv` — per-channel double-buffered
  frame store: raster-order write in the source clock domain, CDC
  handoff of "latest complete buffer index" to the shared clock domain.
- `rtl/scaler/nn_scaler.sv` — per-channel nearest-neighbor scaler,
  mapping the output's (x, y) into that channel's own native resolution
  before it hits `frame_buffer_channel.rd_addr`. Fixed-point multiply,
  not yet an accumulator (see module comment for the tradeoff).
- `rtl/compositor/output_crossbar.sv` — N-channel select, latched only
  at the output's own frame boundary, reads the selected channel's
  latest-complete buffer for that whole frame.
- `rtl/output/timing_gen.sv` — parametrized de/frame_start/x/y generator.
- `sim/models/video_source_sim.sv` — sim-only free-running test-pattern
  generator per input, each at an independently-chosen clock period and
  resolution, to emulate 4 unsynchronized, mismatched-resolution HDMI
  sources.
- `sim/tb_top.sv` — wires it all together, drives channel-select changes
  (including deliberately mid-frame) and self-checks both the switch
  (no cross-frame mixing) and the scaler (decoded pixel position matches
  an independent nearest-neighbor reference model).

Test pattern content is `{channel_id, y, x}`, not real RGB — this track
is proving pipeline/CDC/scaling correctness, not image quality, so
keeping payload trivial keeps simulation fast and the self-check able to
verify exact source and position. Real pixel data (10-bit YCbCr/RGB) is
a width parameter change later, not a structural one.

**Status: done and passing** (see [../sim/README.md](../sim/README.md)) —
switching and nearest-neighbor scaling both proven in simulation across
4 asynchronous, mismatched-resolution sources.

## Deferred out of Phase 1 scope

- Bilinear (or better) scaling — nearest-neighbor only for now; would add
  fractional weights and up to 4 source reads instead of 1.
- Multi-layer compositing (Phase 2).
- Any daughtercard/FMC-spec work (Phase 3).
- Real HDCP/EDID handling.
- Real HDMI receiver front-end / hardware bring-up track (separate from
  this logic/simulation track, not started).
