# Carrier board spec (SOM + custom carrier)

Status: draft, pre-schematic. Captures the SOM choice and the GTH
transceiver budget/mapping. The cross-quad clocking question that
blocked pin assignment is now resolved (see below) — full 4-in+1-out
native HDMI fits on the Trenz TE0807's 16 GTH lanes.

## SOM choice: Trenz TE0807 (recommended)

**Trenz Electronic TE0807** (e.g. TE0807-03-7DE21-AZ: XCZU7EV-1FBVB900E,
4GB DDR4, 128MB QSPI boot flash), ~$1,367 (Jul 2026, DigiKey/Trenz shop).
Confirmed directly from Trenz's own [TE0807 TRM](https://wiki.trenz-electronic.de/display/PD/TE0807+TRM):

- **All 20 of the chip's high-speed transceivers are wired to the
  module's board-to-board connectors** — 16 GTH (banks 224-227, 4 lanes
  each) + 4 GTR (bank 505) — nothing consumed internally by the module
  itself. This is the whole point of going SOM+carrier: an eval board
  pre-spends transceivers on its own onboard peripherals (PCIe, SFP+,
  etc.); a bare SOM spends none, leaving the full budget for us.
- 4x B2B connectors (J1-J4), "Razor Beam LP Slim Terminal Strip," 0.5mm
  pitch, 160 contacts each (Samtec-class — exact Samtec part number and
  KiCad footprint still needed, see open items).
- Same XCZU7EV chip already used in prior research, so the "native HDMI
  needs direct-GTH" reasoning and 3-GTH-per-port cost from
  hardware-selection.md carries over unchanged.

**Alternative noted, not chosen**: Enclustra Andromeda XZU65 also
supports a ZU7EV variant and markets itself explicitly for
transceiver-heavy video applications, but no pricing was obtainable in
this research pass — worth a quote if Trenz doesn't pan out.

## GTH budget: 15 needed, 16 available — but not that simple

Naive math looks fine: 4 native HDMI in + 1 native HDMI out = 15 GTH
lanes, TE0807 has 16 GTH. **But the 16 GTH lanes aren't 16 independent
slots — they come in 4 fixed quads of 4 lanes each (banks 224, 225, 226,
227), and lanes within a quad normally share a reference clock.**

If every HDMI port needs to run its own genuinely arbitrary, independent
pixel rate (which is the whole point of the native-capture requirement),
each port's 3 TMDS lanes ideally want to come from the *same* quad, so
they share one coherent reference clock. That gives exactly **4 clean
one-port-per-quad slots** (3 of 4 lanes used, 1 spare per quad) — enough
for 4 independently-clocked native ports, not 5. There's no clean 5th
quad for the output.

**Resolved** (was the top open question — now answered from Xilinx's own
docs, read directly rather than assumed):

Read UG578 (UltraScale Architecture GTY Transceivers User Guide) and
UG576 (the GTH-specific equivalent) directly — both describe the same
architecture. Key facts, quoted/paraphrased from UG578 v1.3 Chapter 2
("Reference Clock Selection and Distribution"):

- Every quad has dedicated `GTNORTHREFCLK`/`GTSOUTHREFCLK` ports that let
  it source its reference clock from **up to two quads above or below**
  it, via **dedicated cross-quad clock routing tracks** — this is a
  real, documented, first-class feature, not a workaround.
- The only budget limit: **2 routing tracks per direction**. A quad can
  relay a clock to at most 2 neighbors in each direction simultaneously,
  and that budget can be consumed by relay chains further down the line
  (e.g. if Q(n-1) is already relaying from Q(n-3), Q(n) may lose access
  to Q(n-2)).
- There *is* a line-rate-based restriction, but it only bites at high
  speed: sharing is unrestricted below 16.375 Gb/s, allowed with care up
  to 28.21 Gb/s (UltraScale+), and disallowed above that. **HDMI TMDS at
  4K60 runs ~5.94 Gb/s per lane** — comfortably inside the unrestricted
  region. This mechanism was never actually at risk for our use case.
- Confirmed XCZU7EV's specific layout (via a separate search hit, not
  just the general architecture doc): quads **224, 225, 226, 227 are
  physically sequential in the same transceiver column** (X0Y0-3,
  X0Y4-7, X0Y8-11, X0Y12-15) — i.e. already adjacent in exactly the
  order needed for north/south relay between neighbors.

**What this means for the 5th port**: source one reference clock
locally in quad 225 (its own dedicated `GTREFCLK0`/`1` pins), and relay
it one hop south into 224 and one hop north into 226 via
`GTSOUTHREFCLK`/`GTNORTHREFCLK`. That's 1 of the 2 available tracks
used at each of the two quad boundaries involved — nowhere near the
budget ceiling. The output port's 3 TMDS lanes can then be built from
one spare lane each in quads 224, 225, and 226, all frequency-coherent
because they share the one physical reference clock. Quad 227's spare
lane isn't needed for this and stays free.

**Remaining caveats, not blockers**: Xilinx's own guidance notes a
fully-local reference clock has the best jitter performance, and
cross-quad sourcing adds a (small, but real) amount of routing — worth
confirming with an actual eye-diagram measurement during bring-up rather
than assumed away, especially since native/custom timings already push
outside the range Xilinx's own IP was validated against. And this
analysis is architecture-level (from the user guide's general
description); final confirmation of exact pin-level feasibility for
*this specific* GTH quad arrangement belongs in Vivado's pin planner
once schematic capture starts — but there's no remaining reason to
believe the 4-in+1-out design doesn't fit.

## GTH allocation (unblocked — see resolution above)

| Quad (bank) | Lanes | Assignment |
|---|---|---|
| 224 | 4 | HDMI IN 1 (3 lanes) + 1 lane -> HDMI OUT (shares quad 225's ref clock via GTSOUTHREFCLK) |
| 225 | 4 | HDMI IN 2 (3 lanes) + 1 lane -> HDMI OUT (local reference clock, relayed to 224 & 226) |
| 226 | 4 | HDMI IN 3 (3 lanes) + 1 lane -> HDMI OUT (shares quad 225's ref clock via GTNORTHREFCLK) |
| 227 | 4 | HDMI IN 4 (3 lanes) + 1 spare, unused |
| GTR (bank 505) | 4 | Not used for HDMI (see below); reserved/spare |
| HDMI OUT | 3 (borrowed) | 1 lane each from quads 224, 225, 226 (see above) |

GTR transceivers are *not* used for any HDMI port: their typical ~6Gbps
ceiling leaves too little margin over 4K60's ~5.94Gbps-per-lane TMDS
rate. GTH (16.3Gbps-rated) is the safe choice for all video, consistent
with hardware-selection.md.

**One nuance worth being precise about**: "shares quad 225's reference
clock" does *not* force HDMI OUT and HDMI IN 2 to run the same line
rate — each lane normally gets its own per-channel CPLL, which
multiplies/divides the shared reference independently, so IN 2 and OUT
can still target different rates. What sharing *does* mean: both are
constrained to whatever rates are reachable from the *same* base
reference frequency at any given moment (a CPLL's multiply/divide ratio
set is discrete, not arbitrary). If IN 2 and OUT both need to hit
genuinely arbitrary, unrelated custom pixel rates *simultaneously*, the
reference clock architecture (see "Not yet designed" below) needs to
account for that coupling — likely by feeding quad 225's shared
reference from a programmable synthesizer that can retune, rather than
assuming full independence. Not a blocker, but a real design constraint
to carry into that step, not an afterthought.

## Control plane: keep it off the GTH budget

With GTH this tight, the carrier should not spend any on PCIe or other
control-plane links. The Zynq UltraScale+ PS has hardened Gigabit
Ethernet (GEM) controllers that talk to an external PHY over ordinary
RGMII/SGMII I/O — not GTH — so networking/control access costs regular
I/O pins, not transceivers. Recommendation: one external Gigabit
Ethernet PHY on RGMII from the PS, no PCIe on this board rev.

## Not yet designed (real schematic work, not done here)

- HDMI connector-side circuitry per port: AC-coupling caps on the 3 TMDS
  data pairs, ESD protection, 5V-tolerant level shifting for
  HPD/CEC/DDC, EDID emulation (EEPROM or FPGA-driven) per input.
- Reference clock generation: each of the 4 input ports likely needs an
  independently-programmable clock synthesizer (e.g. Si5341/Si5345
  class) feeding its quad's reference pins, not a fixed oscillator.
  Quad 225's synthesizer output also feeds HDMI OUT's borrowed lane (via
  the cross-quad relay above) — the synthesizer/architecture choice
  needs to account for the IN2/OUT coupling noted above, not just pick
  4 independent chips and assume it's fully solved. Part selection not
  done yet.
- Power: TE0807 needs specific input rail(s) per its TRM (not
  transcribed here yet) — carrier needs its own regulation for HDMI
  connector-side logic (3.3V/5V) on top of whatever the module needs.
- Exact Samtec B2B connector part number + KiCad footprint/symbol for
  the 4x160-contact 0.5mm-pitch connectors.
- Explicit **no-HDCP** stance: not implementing HDCP (licensing/legal
  scope, consistent with MiSTer's own position) — protected/encrypted
  HDMI sources will not display. Worth stating plainly in end-user docs
  later, not just here.

## Open items before ordering the SOM or starting schematic capture

- Get the exact Samtec B2B connector part number from Trenz (for KiCad
  footprint sourcing).
- Decide the reference clock synthesizer architecture, accounting for
  the quad-225/HDMI-OUT coupling noted above.
- Confirm the GTH allocation above at the Vivado pin-planner level once
  schematic capture starts, as a final sanity check on this
  architecture-level analysis — not expected to change the outcome, but
  worth doing before pins are committed to copper.
- No SOM purchase has been made yet. This doc is the basis for a
  decision, not a confirmation of one.
