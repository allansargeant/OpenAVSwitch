# System architecture

Status: draft, pre-hardware. This is the working model for the whole
project; expect it to change as Phase 1 surfaces real constraints.

## Why not stock MiSTer

MiSTer's DE10-Nano (Cyclone V SoC) has no HDMI input hardware at all, and
after the HPS (ARM/Linux) bridge takes its cut of fabric and the single
DDR3 controller's bandwidth, there isn't enough logic or memory bandwidth
left to run even one capture+scale channel at 4K, let alone four. It's a
retro-console emulation platform, not a video-processing one. This project
is only "MiSTer-inspired" in spirit (open, reproducible, community-buildable
FPGA hardware) — the silicon target is different.

## Target device class: Zynq UltraScale+ MPSoC (or equivalent)

Recommended starting point: **Xilinx/AMD Zynq UltraScale+ MPSoC** (e.g. a
ZCU106-class eval board for prototyping). Rationale:

- **PS (processing system):** quad-core Arm Cortex-A53 running Linux —
  handles control plane, configuration, EDID/HPD management, UI/network
  API, and (later) driver integration for third-party capture cards.
- **PL (programmable logic):** UltraScale+ fabric has the DSP slices,
  BRAM, and UltraRAM needed for per-channel scalers and line buffers.
- **Hardened PCIe root complex/endpoint** and high-speed GTH transceivers
  — needed for both custom card-to-card interconnect and (potentially)
  third-party PCIe capture cards.
- **DDR4 memory controller** with far more real bandwidth than MiSTer's
  shared DDR3 (see budget below).

This is a recommendation, not a commitment — Versal (adds AI Engines /
hardened video-friendly DSP, higher cost) or a comparable Xilinx/AMD part
are reasonable alternatives if Phase 1 shows we need more headroom sooner.
Non-Xilinx MPSoCs with similar PS+PL+PCIe shape would work in principle but
lose the FMC-mezzanine ecosystem described below.

## Core design principle: continuous capture, not live switching

Real seamless switchers (Aquilon, E3) don't switch a raw incoming signal —
they continuously capture and pre-scale *every* connected input into memory
whether or not it's on air, and the output stage simply chooses which
already-live, already-scaled buffer(s) to read each frame. Switching is a
read-pointer/compositor change, not a re-sync of the video path, which is
why it's glitch-free.

This project follows the same model:

1. **Capture stage** (per input): receiver front-end -> format
   detect/EDID/HPD -> continuous write into a per-channel frame buffer in
   DDR4. Runs regardless of whether that input is currently on output.
2. **Scale stage** (per input or per layer): reads from a channel's frame
   buffer, scales to the size/position needed for its current layer
   assignment, writes to a layer buffer. Because it's memory-to-memory,
   an input can feed multiple layers at different sizes simultaneously.
3. **Compositor/crossbar**: for each output frame, reads the layer buffers
   assigned to that output, alpha-blends/composites them, and drives the
   output timing generator. Changing what's on air is just changing which
   layer buffer(s) the compositor reads — no re-lock, no black frame.
4. **Output stage**: timing generation + transmitter (HDMI/SDI/DP).

Phase 1 collapses this to the simplest case (4 capture channels, 1 layer,
1 output) but the pipeline shape is the same one the later multi-layer,
multi-output, multi-card system needs — this is why Phase 1 is worth
building even though it's "just" a switcher.

## Memory bandwidth, rough budget

Uncompressed 4K60 4:4:4 8-bit is ~1.49 GB/s per stream, one direction.
For 4 input channels + compositing + 1 output, counting write+read at each
stage (capture write, scale read+write, composite read, output read),
order-of-magnitude demand lands around 10-15 GB/s sustained. This is well
beyond stock MiSTer's single shared DDR3 controller, and is the main
quantitative reason for moving to a DDR4-class device — a ZCU106-class
board's DDR4 (~19+ GB/s theoretical) has real headroom; exact margin needs
to be validated against actual memory controller efficiency once we're
building, not assumed.

8K (Phase 6+) roughly quadruples all of the above — plan on it needing
either a bigger/second device or a fundamentally different memory
architecture (e.g. splitting channels across multiple DDR controllers or
devices), not just "the same design, faster."

## HDMI capture must be native (direct-GTH), not chip-based

Decision (2026-07-13): HDMI inputs and the output must support arbitrary
custom timings and refresh rates, not just standard CEA-861/SMPTE
formats. This isn't a nice-to-have — it's the same reason MiSTer itself
has to deal with things like 15kHz and other non-standard rates from
original/retro hardware, and it rules out the "chip-based receiver"
approach for HDMI specifically.

Fixed-function HDMI receiver/bridge chips (e.g. Lontium LT6911-class
HDMI-to-MIPI parts) are built for consumer CEA-861 compliance and can't
be trusted to lock onto or pass through arbitrary non-standard sync
patterns. So HDMI capture and output use **direct-GTH** instead: Xilinx's
HDMI RX/TX Subsystem IP has a "Native Video Interface" / custom-timing
mode (with a self-written video timing controller instead of the
standard one) specifically for this — confirmed capable, not a stretch.

This is a real cost, not a free choice: direct-GTH costs 3 GTH
transceiver channels per HDMI port (in or out), and that transceiver
budget turns out to be the actual limiter on how many native HDMI ports
fit on a single board — see
[hardware-selection.md](hardware-selection.md) for the math and its
consequences for board/phase planning.

**SDI is exempt from this constraint.** SDI is already tightly
standardized (SMPTE), so a chip-based receiver (e.g. Semtech GS12190,
~1 GTH lane/channel vs HDMI's 3) is fine there — "capture must be native"
is specifically an HDMI/custom-format concern, not a blanket rule against
all receiver chips.

## Modularity: I/O daughtercards

Long-term goal is a card-cage model: a host/control card plus pluggable
I/O cards (HDMI, SDI, DisplayPort, third-party capture). Recommended
physical/electrical basis: **FMC / FMC+ (VITA 57.1 / 57.4)** rather than a
custom connector —

- Mature ecosystem: HDMI-in, SDI, and DisplayPort FMC mezzanine cards
  already exist commercially (Opsero, Avnet, others) and are usable
  during Phase 1/3 without us designing capture front-ends from scratch.
- VITA 57.1/57.4 already define high-speed serial lane counts, sideband
  I2C for card ID/EEPROM, and power rails — we don't need to invent this.
- Defers the harder problem (a true chassis backplane with hot-plug,
  redundant power, multiple slots) to a later phase, once we know what
  the cards actually need to carry.

See [io-card-spec.md](io-card-spec.md) for the draft card-level spec.
Genlock/reference-clock distribution across cards is called out there as
a first-class requirement, not an afterthought — it's what makes
multi-card seamless switching possible at all.

## Open question: third-party capture card support (e.g. Blackmagic DeckLink)

Two different things could be meant by "support DeckLink," with very
different architectural consequences:

- **(A) Software/driver integration**: DeckLink as a PCIe device, using
  Blackmagic's Desktop Video SDK/driver to pull frames into a Linux host.
  Blackmagic's official driver is **x86_64-only** — it is not vendor
  -supported on Arm Linux, which the Zynq PS is. Doing this would push
  the "host" role onto a separate x86 compute card in the chassis (e.g. a
  COM Express/mini-ITX module) rather than the FPGA SoC's own Arm cores.
- **(B) Signal-level integration**: treat a DeckLink (or any capture
  card) purely as a source of an SDI/HDMI/DP signal, physically looped
  into one of our own capture daughtercards. No vendor SDK, no driver
  compatibility risk, and it's work we need to do anyway for our own I/O
  cards.

Recommendation: default to (B) for now — it's lower-risk and reuses
Phase 1/3 work directly. Leave (A) as a possible later addition (would
require adding an x86 host card to the chassis design) if there's a
concrete need to ingest DeckLink cards that aren't physically accessible
for a cable loop. This doesn't need to be decided before Phase 1.
