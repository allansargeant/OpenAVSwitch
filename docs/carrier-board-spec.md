# Carrier board spec (SOM + custom carrier)

Status: draft, pre-schematic. Captures the SOM choice and the GTH
transceiver budget/mapping. **Correction from an earlier version of this
doc**: a previous pass concluded 4-in+1-out native HDMI fits cleanly on
TE0807's 16 GTH by having HDMI OUT borrow lanes across quads. That
conclusion was wrong in an important way — see "Corrected conclusion"
below. Current answer: **3 fully-independent native inputs + 1
fully-independent native output fit cleanly; the 4th input needs either
a compromise or a second board.**

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

**What the earlier pass got wrong**: it treated "HDMI OUT borrows a lane
from quad 225" as giving OUT its own independent rate, since each lane
has its own per-channel CPLL. That's true in isolation, but it missed
what the CPLL can actually *do* with a shared reference. Worked out the
math (UG576 Equation 2-1/2-2, Table 2-11): CPLL output = f_ref x
(N1 x N2 / M), line rate = CPLL output x 2 / D, with N1 in {4,5}, N2 in
{1..5}, M in {1,2}, D in {1,2,4,8}. Enumerating every combination gives
only **29 distinct discrete ratios** between line rate and reference
frequency — not a continuum. So if quad 225's reference is fixed to
whatever HDMI IN 2 needs *right now* (a live, continuously-captured
arbitrary-rate source that must never be disturbed, per architecture.md's
core "continuous capture" principle), HDMI OUT's achievable rate isn't
arbitrary — it's restricted to one of those ~29 ratios *times whatever
IN 2's reference currently is*. If OUT needs to drive some unrelated
display at a rate that isn't one of those 29 ratios away from IN 2's
current reference, it simply can't, without retuning the shared
reference and disturbing IN 2's live capture. That's a real conflict
with the native/arbitrary-rate requirement for OUT, not a minor caveat.

**The underlying reason, more generally**: cross-quad clock *sharing*
doesn't create a new independent reference domain — it only extends the
reach of an *existing* one to more lanes. With 4 physical quads, each
with its own local reference clock pins, there are at most **4
independently-and-arbitrarily-tunable reference domains available on
this SOM, full stop** — no routing trick changes that count. 5
genuinely independent arbitrary-rate ports need 5 independent reference
sources, and TE0807 only has 4.

## Corrected conclusion and GTH allocation

**3 fully-independent native ports fit cleanly, one per quad, no
sharing, no coupling:**

| Quad (bank) | Lanes | Assignment |
|---|---|---|
| 224 | 4 | HDMI IN 1 (3 lanes) + 1 spare, unused |
| 225 | 4 | HDMI IN 2 (3 lanes) + 1 spare, unused |
| 226 | 4 | **HDMI OUT** (3 lanes) + 1 spare, unused |
| 227 | 4 | HDMI IN 3 (3 lanes) + 1 spare, unused |
| GTR (bank 505) | 4 | Not used for HDMI (see below); reserved/spare |

GTR transceivers are *not* used for any HDMI port: their typical ~6Gbps
ceiling leaves too little margin over 4K60's ~5.94Gbps-per-lane TMDS
rate. GTH (16.3Gbps-rated) is the safe choice for all video, consistent
with hardware-selection.md.

This gives 3 native inputs + 1 native output, all genuinely
independent — no rate coupling, no shared-reference conflict. **The 4th
input doesn't fit on this SOM with full independence, and needs one of:**

1. **Defer it** to a second TE0807/carrier (mirrors the project's own
   eventual card-cage vision — each board is a natural stand-in for a
   future chassis slot, consistent with how hardware-selection.md
   already reasoned about staging).
2. **Accept the coupling for one input specifically**, if one of the 4
   inputs can tolerate being rate-constrained relative to another
   port's reference (e.g. if it's expected to mostly see standard
   formats rather than truly arbitrary ones) — this reintroduces exactly
   the kind of compromise the native-capture requirement was meant to
   rule out, so it's a real trade-off, not a free win.
3. **Move to a device/board with more independent quads** — noted as an
   option in hardware-selection.md already (transceiver-richer device
   family), still not researched in depth.

No default picked here — this is a real decision, flagged for you
rather than assumed.

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
- Reference clock generation: each of the 3 native inputs and the 1
  native output needs its own independently-programmable clock
  synthesizer (e.g. Si5341/Si5345 class) feeding its own quad's
  reference pins — 4 independent synthesizer outputs, one per quad, no
  sharing between them (per the corrected conclusion above). Part
  selection not done yet.
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

- **Decide how to handle the 4th input** (defer to a second board,
  accept a rate-coupling compromise on one port, or research a
  transceiver-richer device) — the main open decision now.
- Get the exact Samtec B2B connector part number from Trenz (for KiCad
  footprint sourcing).
- Decide the reference clock synthesizer part (4 independent outputs
  needed, one per quad — simpler now that there's no cross-quad sharing
  to design around).
- Confirm the GTH allocation above at the Vivado pin-planner level once
  schematic capture starts, as a final sanity check on this
  architecture-level analysis — not expected to change the outcome, but
  worth doing before pins are committed to copper.
- No SOM purchase has been made yet. This doc is the basis for a
  decision, not a confirmation of one.
