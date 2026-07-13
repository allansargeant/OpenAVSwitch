# Phase 1 plan — 4-in / 1-out HDMI seamless switcher

Status: in progress. This pins down concrete choices so RTL work has a
fixed reference instead of re-deciding things per module.

## Target hardware (real board, later)

Researched, not yet purchased. See [hardware-selection.md](hardware-selection.md)
and [carrier-board-spec.md](carrier-board-spec.md) for the full
reasoning, which has evolved several times:

1. First pass proposed ZCU106-class + generic HDMI FMC mezzanines.
2. Found GTH transceiver budget, not compute/DDR bandwidth, is the real
   constraint; briefly considered chip-based (MIPI-CSI-2) HDMI receivers
   to save budget, then ruled that out — HDMI capture must support
   arbitrary custom timings/refresh rates (architecture.md), and
   chip-based receivers are built for consumer CEA-861 compliance, not
   arbitrary sync. All HDMI ports must be direct-GTH.
3. That reopened the transceiver math on eval boards (staged ZCU106
   plan) before landing on the current, final approach below.
4. **Current**: custom carrier board around a Zynq UltraScale+ SOM
   (**Trenz TE0807**, XCZU7EV) instead of an eval board — a bare SOM
   exposes its full 16 GTH lanes instead of pre-spending them on
   onboard peripherals. Even so, one TE0807's 4 GTH quads only support
   **3 fully-independent native inputs + 1 native output** without a
   real rate-coupling compromise (see carrier-board-spec.md's corrected
   clocking analysis). **Decided: the 4th input is deferred to a second
   TE0807/carrier board** rather than compromised — Phase 1's hardware
   now spans two boards, not one.

Still not purchased. KiCad project skeleton exists
(`hardware/carrier-board/`) for the first board (3 native in + 1 native
out); nothing in the RTL below depends on any of this, deliberately, so
hardware selection doesn't block logic-level work.

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
