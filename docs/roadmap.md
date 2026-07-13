# Roadmap

Phased so each stage produces something real and de-risks the next one,
rather than trying to build the modular chassis system up front.

## Phase 0 — Architecture & specs (current)
Repo scaffold, [architecture.md](architecture.md), draft
[io-card-spec.md](io-card-spec.md). No hardware or RTL yet.

## Phase 1 — 4-in / 1-out HDMI 4K seamless switcher (custom carrier board)
The concrete near-term goal. Hardware plan evolved from "buy an eval
board" to a **custom carrier board around a Zynq UltraScale+ SOM**
(recommended: Trenz TE0807, XCZU7EV) — see
[hardware-selection.md](hardware-selection.md) and
[carrier-board-spec.md](carrier-board-spec.md) for why: native HDMI
(arbitrary custom timings/rates, not just CEA-861/SMPTE) requires
direct-GTH capture on every port, and no off-the-shelf eval board has
enough spare transceiver budget for 4 native inputs + 1 native output.
A bare SOM exposes its full transceiver budget instead of pre-spending it
on onboard peripherals we don't need. Still: 4 continuously-captured
HDMI inputs, up to 4K, one output, switching between them with no
glitch, proving the capture -> frame-buffer -> scale -> crossbar ->
output pipeline described in architecture.md — the functional goal
hasn't changed, only how the hardware gets there.

**Logic/simulation track: done** — see [phase1-plan.md](phase1-plan.md)
and [../sim/README.md](../sim/README.md). Switching and nearest-neighbor
scaling both proven in Icarus Verilog simulation. **Hardware track:
SOM/board researched, carrier board spec drafted, not yet built** — an
unresolved GTH cross-quad clocking question (carrier-board-spec.md) needs
answering before schematic capture starts, and KiCad still needs
installing.

**Exit criteria:** switch between any of 4 live 4K sources on the single
output with no visible black frame / resync, and independent scale
(aspect-correct fit, at minimum) per source.

## Phase 2 — Multi-layer compositing
Add layer buffers and alpha blending on the same hardware: multiple inputs
on screen simultaneously (PIP, side-by-side), independent scale/position
per layer. Still single board, still no daughtercards.

## Phase 3 — Modular I/O daughtercards
Formalize and build to the io-card-spec: swap the fixed HDMI FMC mezzanine
for a defined card interface, add a second card type (e.g. SDI or DP) to
prove the spec isn't HDMI-specific. Genlock distribution across cards
gets exercised for real here.

## Phase 4 — Chassis / card-cage productization
Backplane, multiple slots, host/control card separated from I/O cards,
power distribution. This is where it starts looking like an actual
rack-mount mainframe rather than a dev-board stack.

## Phase 5 — Third-party capture card support
Resolve the DeckLink-class question from architecture.md — signal-loop
integration first; software/SDK/driver integration only if a concrete
need shows up and only with an x86 host card added to the chassis.

## Phase 6 — 8K
Revisit memory/compute budget seriously — likely needs a bigger device,
multiple devices, or a different memory architecture, not just faster
clocks on the Phase 1 design.
