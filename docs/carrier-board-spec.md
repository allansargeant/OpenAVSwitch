# Carrier board spec (SOM + custom carrier)

Status: draft, pre-schematic. Captures the SOM choice, the GTH
transceiver budget/mapping, and this board's finalized scope: **3 fully-
independent native HDMI inputs + 1 fully-independent native HDMI
output**, one GTH quad each. (An earlier pass in this doc's history
concluded 4-in+1-out fit on one board via cross-quad lane sharing —
wrong, see "What the earlier pass got wrong" below for why.) The 4th
input is deferred to a second TE0807/carrier board (decided 2026-07-13),
not part of this board's design.

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
  pitch, 160 contacts each. **Exact part numbers found and confirmed**
  (Trenz's own dedicated ["5.2 x 7.6 SoM ST5 and SS5 B2B Connectors"](https://wiki.trenz-electronic.de/display/PD/5.2+x+7.6+SoM+ST5+and+SS5+B2B+Connectors)
  page, cross-referenced against Samtec's catalog): module side (already
  populated on TE0807) is Samtec **ST5** series, Trenz ref REF-192552-02;
  the carrier-side mating socket we need to place is Samtec
  **SS5-80-3.50-L-D-K-TR** (Trenz ref REF-192552-01) — 80 positions/row,
  dual row = 160 contacts, 3.5mm stack height. KiCad footprint + symbol
  + 3D model available for this exact part from both the official KiCad
  footprint library ([KiCad/Connectors_Samtec.pretty](https://github.com/KiCad/Connectors_Samtec.pretty))
  and SnapEDA — no need to hand-build one. Need 4 of these (J1-J4).
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
independent — no rate coupling, no shared-reference conflict.

**Decided (2026-07-13): the 4th input is deferred to a second
TE0807/carrier board**, not squeezed onto this one. This board's scope
is now fixed: 3 native HDMI inputs + 1 native HDMI output, all fully
independent. Mirrors the project's own eventual card-cage vision — this
board is a natural stand-in for a future chassis slot, and Phase 1's
overall 4-in+1-out goal (docs/roadmap.md) is still reached, just across
two boards instead of one. The other two options considered (accepting a
rate-coupling compromise on one port, or a transceiver-richer device)
were rejected: the first reintroduces exactly the limitation the
native-capture requirement exists to avoid, and the second is unresearched
and likely costs more / loses the hard Arm PS.

## Control plane: keep it off the GTH budget

With GTH this tight, the carrier should not spend any on PCIe or other
control-plane links. The Zynq UltraScale+ PS has hardened Gigabit
Ethernet (GEM) controllers that talk to an external PHY over ordinary
RGMII/SGMII I/O — not GTH — so networking/control access costs regular
I/O pins, not transceivers. Recommendation: one external Gigabit
Ethernet PHY on RGMII from the PS, no PCIe on this board rev.

## HDMI connector-side circuitry (per port, standard practice — not yet in KiCad)

- **Connector**: standard 19-pin Type-A HDMI receptacle (e.g. Amphenol
  GSD1S211-style or Molex 47960-series).
- **TMDS 3 data pairs**: AC-coupled (100nF 0402, standard for GTH RX
  inputs) straight to the SOM's GTH RX pins — no receiver chip, per the
  native-capture requirement. Xilinx's own placement guidance is to keep
  the caps close to the FPGA/SOM side.
- **DDC (I2C)**: bus is 5V on the source side; needs a bidirectional
  level translator (e.g. TI TXS0102 or PCA9306-class) between the
  connector's 5V DDC and the SOM's 3.3V/1.8V I2C, since we're the sink
  presenting our own EDID.
- **HPD (hot-plug detect)**: sink-driven output to the source, 5V logic
  — same level-translator part can usually do double duty, or a simple
  open-drain/level-shifted GPIO.
- **CEC**: optional, deferred — not required for basic capture/display
  and skipping it simplifies the first revision.
- **ESD protection**: a dedicated HDMI ESD array IC at the connector
  (e.g. ON Semi NUF2042-class) across TMDS + DDC + HPD lines — standard,
  cheap, and connector-adjacent placement matters for effectiveness.
- **EDID**: recommend **FPGA-driven emulation** (a soft I2C slave under
  our own control) over a fixed pre-programmed EEPROM. A static EEPROM
  can't tell a source "yes, I support this specific custom timing" —
  the whole point of native capture is flexibility, so EDID needs to be
  equally flexible, not hardcoded at manufacture time. A physical
  EEPROM is a fallback if the soft-I2C-slave approach proves harder than
  expected during bring-up, not the primary plan.

None of this is in KiCad yet — topology/approach chosen, exact part
numbers (connector, level translator, ESD array) and schematic capture
still to do.

## Power

TE0807 needs a **single 3.3V input rail** from the carrier — the module
generates all its own internal rails (VCCINT, MGTAVCC, etc.) via onboard
SMPS, confirmed from Trenz's own TRM search summary (full PDF not
re-fetched this pass to save effort; worth double-checking the actual
TRM before finalizing the power tree). Two things the carrier still
owns:

- **Per-bank VCCO**: the SOM's PL I/O banks get their VCCO supplied by
  the carrier via dedicated B2B connector pins, not generated on-module
  — carrier picks the voltage per bank (1.8V/2.5V/3.3V) to match what
  each bank's I/O actually needs (e.g. HDMI level-translator-side logic).
- **Power sequencing**: TE0807 documents a 3-step sequence (core rails,
  then main supply, then I/O voltages) — the carrier's VCCO rails need
  to come up *after* the module's internal core rails are stable, likely
  via a power-good handshake signal rather than a fixed delay. Not
  designed yet; needs the full TRM's exact sequencing requirements
  before schematic capture.
- Separately, carrier-side HDMI circuitry (level translators, ESD ICs)
  needs its own 3.3V/5V rails, on top of the SOM's 3.3V input — ordinary
  linear/switching regulation, no unusual requirements.

## Not yet designed (real schematic work, not done here)

- **Reference clock generation — part selected**: one **Silicon Labs
  Si5341A** (10-output, any-frequency clock generator, ~$18) feeds all 4
  quads' reference pins from its 10 independent outputs — no sharing
  between them, 6 outputs spare for future use (e.g. a genlock/reference
  distribution output to the second carrier board or future
  daughtercards, per io-card-spec.md's genlock requirement). Well-suited
  on paper: Silicon Labs explicitly references this part in their own
  timing reference designs for Kintex/Virtex UltraScale GTH transceiver
  applications, differential output range 100Hz-1028MHz (comfortably
  covers the reference frequencies GTH's CPLL needs), and 0.001 ppb
  tuning resolution — effectively continuous, not discretely stepped
  like the CPLL's own ratios, so it can compensate for whatever exact
  reference the CPLL math needs for a given arbitrary target rate.
  Configured over I2C/SPI with Silicon Labs' ClockBuilder Pro tool. Not
  yet validated against real hardware — the usual caveat about
  architecture-level research vs. bring-up measurement applies here too.
- Explicit **no-HDCP** stance: not implementing HDCP (licensing/legal
  scope, consistent with MiSTer's own position) — protected/encrypted
  HDMI sources will not display. Worth stating plainly in end-user docs
  later, not just here.

## Open items before ordering the SOM or starting schematic capture

- Confirm the GTH allocation above at the Vivado pin-planner level once
  schematic capture starts, as a final sanity check on this
  architecture-level analysis — not expected to change the outcome, but
  worth doing before pins are committed to copper.
- Pick exact connector/level-translator/ESD-array part numbers (topology
  chosen above, specific parts not sourced yet).
- Re-verify TE0807's power sequencing requirements against the full TRM
  (this pass used a search summary, not the primary document).
- No SOM purchase has been made yet. This doc is the basis for a
  decision, not a confirmation of one.
