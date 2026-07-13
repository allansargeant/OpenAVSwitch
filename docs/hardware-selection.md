# Hardware selection (Phase 1)

Status: research complete, board choice recommended but **not yet
purchased**. Findings from web research in July 2026 — re-verify pricing
and part availability before actually ordering, both tend to move fast in
this market.

## Zynq UltraScale+ MPSoC family: confirmed sound

architecture.md's original reasoning holds up: the PS (Arm Cortex-A53 +
Cortex-R5, PCIe root complex) + PL (fabric, GTH transceivers) split is
still the right shape for this project. Confirmed via AMD's docs: the
Xilinx **HDMI 1.4/2.0 RX/TX Subsystem** soft IP drives HDMI directly off
GTH transceivers up to 4Kp60, with no external HDMI receiver/transmitter
chip needed for standard formats. That's a real simplification over
assuming we'd need a discrete receiver IC on every input from day one.

## The actual binding constraint: GTH transceiver budget, not the SoC

Each direct-GTH HDMI port (via the Xilinx HDMI Subsystem IP) costs 3 GTH
transceiver channels (one per TMDS data lane). This turns out to be the
real limiter on reaching 4 simultaneous inputs on one board, not compute
or DDR bandwidth as originally assumed in architecture.md.

**AMD ZCU106** (XCZU7EV, 20 total PL GTH transceivers) breaks down as:
HDMI (onboard, 3), PCIe (4), SFP+ x2 (2), SDI (1), SMA (1), FMC HPC1 (1),
FMC HPC0 (8) — 20 total. Only FMC HPC0's 8 lanes are realistically free
for expansion, which covers at most **2 more** direct-GTH HDMI ports (6 of
8 lanes). That's 3 total HDMI inputs achievable on a single ZCU106 via
the pure direct-GTH approach — not 4.

**ALINX Z7-P** (same XCZU7EV chip, successor to the discontinued AXU7EV)
has no onboard HDMI at all — its single FMC HPC connector carries the
full 8 GTH pairs **plus 59 LVDS pairs** for expansion. Same 2-port cap if
using direct-GTH HDMI, but the 59 LVDS pairs are the interesting part —
see below.

## How to actually reach 4 inputs: chip-based receivers, not raw GTH

Two ways to add an HDMI input to a Zynq UltraScale+ design:

1. **Direct-GTH** (Xilinx HDMI Subsystem IP): simplest logic, but costs 3
   scarce GTH channels per port — caps out around 2-3 total ports on
   either board above.
2. **Receiver-chip-based**: an HDMI receiver IC on the daughtercard does
   its own TMDS-rate clock/data recovery and hands off decoded video to
   the host FPGA over ordinary high-speed parallel/LVDS I/O or MIPI
   CSI-2 — consuming *zero* GTH budget. This is exactly what
   `docs/io-card-spec.md`'s "already-deserialized data" case anticipated,
   now with a concrete reason it matters (GTH scarcity) rather than just
   "some cards might work this way."

Confirmed parts along this path: **Lontium LT6911UXC** and **Toshiba
TC358870** both do HDMI-to-MIPI-CSI-2 at 4K, and the XCZU7EV specifically
supports "dual 4Kp60 MIPI connectivity" via a soft MIPI CSI-2 RX
Subsystem IP — a vendor-intended pairing, not a stretch. Z7-P's FMC HPC
explicitly breaking out 59 LVDS pairs (far more than the 8 GTH pairs)
reads as designed with exactly this kind of card in mind.

**This changes the Phase 1 hardware plan**: reaching 4 real HDMI inputs
on one board should target chip-based (MIPI-CSI-2 or LVDS) receiver
daughtercards for at least 2-3 of the 4 channels, reserving direct-GTH
for at most 1-2 ports, rather than assuming all 4 can be naive
direct-GTH. This should also be revisited when Phase 3's daughtercard
spec gets formalized — it's a stronger argument for the FMC+chip
approach than io-card-spec.md currently makes.

## Board options found

| Board | Chip | Price (Jul 2026) | HDMI onboard | Expansion | Notes |
|---|---|---|---|---|---|
| AMD ZCU106 | XCZU7EV | ~$5,300-5,800 | 1 in + 1 out (3 GTH) | HPC0: 8 GTH; HPC1: 1 GTH | Official AMD board, most reference-design/community support |
| ALINX Z7-P | XCZU7EV | ~$2,097 | none | 1x FMC HPC: 8 GTH + 59 LVDS | Successor to discontinued AXU7EV; same chip as ZCU106, ~2.5x cheaper. Confirmed directly from the [Z7-P User Manual](https://github.com/fpgauk/pdf/raw/main/alinx/z7-p/Z7-P_User_Manual.pdf) (not just a secondary source), which also explicitly lists ALINX's "HDMI input/output module" as a compatible FMC card category |
| ALINX AXU7EV | XCZU7EV | ~$2,680 (discontinued) | 2x 4K60 HDMI | 1x FMC LPC | Superseded by Z7-P, which moved HDMI off-board onto FMC cards instead |

**ALINX FH1159**: an existing commercial FMC HPC card advertised as 1x
HDMI in + 1x HDMI out, up to 4K60. Its exact receive path (direct-GTH vs
chip-based) is still **not confirmed** despite a real effort: ALINX's own
product page returns no fetchable content (JS-rendered), a reseller page
403'd, and the community GitHub schematic mirror
([fpgauk/pdf](https://github.com/fpgauk/pdf)) doesn't have an fh1159
folder — it has fh1219, fh1223, fh1224, fh1402, fh7000, fh7621, fh9000,
fh9712, but not fh1159. **Action item: get the actual FH1159 datasheet
before ordering anything.**

One correction from an earlier research pass: an AI-summarized web search
had suggested the FH1159 uses an Analog Devices ADV7611. That doesn't
hold up — ADV7611's own datasheet caps it at UXGA (1600x1200) at a 165MHz
TMDS clock, physically incapable of 4K60. That was very likely a
search-summarization artifact (the search engine's summary conflated
separate, unrelated results), not a real fact about this card. Treat any
single-source, unverified part-number claim from search summaries with
suspicion — cross-check against the part's own datasheet before it goes
in a BOM.

### Accidental but relevant find: ALINX's 12G-SDI card design (FH1219)

While chasing FH1159, the GitHub mirror had `fh1219`'s schematic instead
— a different ALINX product, a 4-channel **12G-SDI** FMC card (title:
"FMC SDI 12G测试板"), not HDMI at all. Worth noting anyway: it uses one
**Semtech GS12190** SDI reclocking transceiver per channel, each needing
only **1 GTH-capable serial pair** — a 3x better transceiver budget than
direct-GTH HDMI's 3 lanes/channel. 4 channels of 12G-SDI fit in 4 GTH
lanes total, comfortably within Z7-P's or ZCU106 HPC0's 8-lane budget,
with room to spare.

This is worth raising as an option, not just a curiosity: professional
live-event switchers (the actual Aquilon/E3 competitive set this project
is modeled on) predominantly use SDI, not HDMI, specifically for this
kind of transceiver/cabling efficiency, plus far better cable-reach and
genlock/reference-sync behavior — all things that matter directly to
this project's "seamless switching" goal. Whether Phase 1 stays
HDMI-first, adds SDI as a second input class, or leads with SDI instead
is a real strategic choice, not something to default into — flagging for
a decision rather than deciding it here.

## Recommendation

Prototype on **ALINX Z7-P** rather than AMD's own ZCU106: same XCZU7EV
chip (so nothing about the RTL/architecture work changes), ~2.5x cheaper,
and its connector layout (all 8 GTH + 59 LVDS pairs on one FMC HPC,
nothing spent on onboard HDMI) is arguably better suited to a
multi-input, chip-based-receiver design than ZCU106's, which pre-spends
3 GTH channels on a single onboard HDMI port we may not even use as one
of our 4 inputs. Trade-off: less official Xilinx/community reference
material than a genuine AMD eval board — worth it for a hobby/community
project on cost grounds, but flagging so it's a conscious choice, not a
default.

If community reference designs / AMD support turn out to matter more
than the ~$3,200 price difference, ZCU106 remains a fine fallback — nothing
here rules it out, it's just tighter on ports.

## Open items before ordering anything

- Confirm FH1159's actual receive path (direct-GTH vs on-card chip) from
  ALINX's datasheet, not just the product page summary — still
  unresolved after a real effort (see above).
- **Decide HDMI-only vs adding/leading with SDI.** The FH1219 find above
  is a real strategic fork, not a footnote: SDI is ~3x more
  transceiver-efficient per channel and is what real Aquilon/E3-class
  hardware actually uses. Staying HDMI-only is simpler (matches the
  original ask, no new receiver-chip integration work) but SDI may be
  worth it if genlock/cable-reach matters as much as the vision docs
  suggest it should eventually.
- Decide the real Phase 1 input mix: e.g. 1-2 direct-GTH ports (simplest
  RTL, reuses Xilinx's subsystem IP almost as-is) + 2-3 chip-based ports
  (LT6911UXC/TC358870 class, needs a MIPI CSI-2 RX Subsystem integration
  we haven't built yet) — or start with fewer than 4 real inputs first
  and grow, mirroring how the logic/simulation track proved the pipeline
  shape before scaling channel count.
- No purchase has been made. This doc is the basis for a decision, not a
  confirmation of one.
