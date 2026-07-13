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

## Superseded: chip-based HDMI receivers ruled out

An earlier version of this doc recommended offloading 2-3 of the 4 HDMI
inputs to chip-based receivers (Lontium LT6911UXC / Toshiba TC358870,
HDMI-to-MIPI-CSI-2) specifically to save GTH budget. **That's now ruled
out**: those chips are built for consumer CEA-861 compliance and can't be
trusted with the arbitrary custom timings/refresh rates this project
needs to support (see architecture.md's new "HDMI capture must be
native" section). All 4 HDMI inputs plus the output need direct-GTH
capture via Xilinx's HDMI Subsystem IP in its custom-timing / Native
Video Interface mode. This is the right call for the requirement, but it
makes the transceiver budget much tighter — worked out below.

## Recalculated GTH budget: native HDMI in+out doesn't fit on one eval board

Direct-GTH HDMI costs 3 GTH channels per port, in **or** out. 4 native
inputs + 1 native output = **15 GTH channels**, before spending anything
on PCIe, Ethernet, or other control-plane I/O.

- **AMD ZCU106** (20 total GTH): onboard HDMI already gives 1 native
  in + 1 native out "for free" (3 GTH, already wired to actual HDMI
  connectors). That leaves 3 more native inputs needed = 9 GTH, but only
  FMC HPC0's 8 lanes are realistically available (HPC1's lone 1 lane
  can't host a 3-lane port by itself) — **1 GTH lane short.**
- **ALINX Z7-P** (also 20 total GTH, XCZU7EV): no onboard HDMI, single
  FMC HPC exposes exactly 8 GTH total — nowhere near the 15 needed for
  all 5 native ports, and its onboard PCIe Gen3 x8 alone already accounts
  for 8 of the chip's 20 GTH.
- **Bigger same-family chips don't help**: XCZU9EG/XCZU11EG/XCZU15EG
  (larger logic, "EG" not "EV") actually have *fewer* GTH transceivers
  (16) than our XCZU7EV (20). The EV suffix is the video-optimized
  variant for this product line — going bigger within Zynq UltraScale+
  MPSoC doesn't trivially buy more transceiver budget.

**Bottom line: 4 native HDMI inputs + 1 native HDMI output do not fit on
a single off-the-shelf ZCU106 or Z7-P's exposed transceiver budget.**
This isn't a board-picking problem, it's a real resource ceiling. Three
realistic ways forward:

1. **Stage it**: build Phase 1 with fewer simultaneous native inputs
   first (e.g. 2 in + 1 out = 9 GTH, comfortably fits either board today)
   and grow to 4 via a second board/FMC slot later. This mirrors how the
   logic/simulation track already proved the pipeline shape before
   scaling channel count, and arguably previews the real product's
   card-cage model better than a single monolithic board would anyway —
   each board becomes a natural stand-in for a future chassis slot.
2. **Move to a transceiver-richer device family**: Kintex/Virtex
   UltraScale+ or RFSoC/Versal parts have far more GTH/GTY channels, but
   Kintex/Virtex UltraScale+ have no hard Arm PS (would need a softcore
   or companion SoC for the control plane), and RFSoC/Versal are a
   significant cost and complexity step up. Not researched in depth yet
   — would need its own pass if this path is chosen.
3. **Custom PCB from day one**: design a board around a Zynq UltraScale+
   EV-class chip with (nearly) all 20 GTH allocated to video I/O instead
   of an eval board's fixed PCIe/SFP+/SDI/SMA allocations. Most
   "correct" for the eventual real product, but a much bigger and slower
   undertaking (schematic, layout, fab, assembly, bring-up) than buying
   an eval board — a real scope decision, not a default.

Not deciding between these here — flagging for a decision, since each
has real cost/schedule consequences.

## Board options found

| Board | Chip | Price (Jul 2026) | HDMI onboard | Expansion | Notes |
|---|---|---|---|---|---|
| AMD ZCU106 | XCZU7EV | ~$5,300-5,800 | 1 in + 1 out (3 GTH) | HPC0: 8 GTH; HPC1: 1 GTH | Official AMD board, most reference-design/community support |
| ALINX Z7-P | XCZU7EV | ~$2,097 | none | 1x FMC HPC: 8 GTH + 59 LVDS | Successor to discontinued AXU7EV; same chip as ZCU106, ~2.5x cheaper. Confirmed directly from the [Z7-P User Manual](https://github.com/fpgauk/pdf/raw/main/alinx/z7-p/Z7-P_User_Manual.pdf) (not just a secondary source), which also explicitly lists ALINX's "HDMI input/output module" as a compatible FMC card category |
| ALINX AXU7EV | XCZU7EV | ~$2,680 (discontinued) | 2x 4K60 HDMI | 1x FMC LPC | Superseded by Z7-P, which moved HDMI off-board onto FMC cards instead |

**ALINX FH1159**: an existing commercial FMC HPC card advertised as 1x
HDMI in + 1x HDMI out, up to 4K60. Its exact receive path (direct-GTH vs
chip-based) was never confirmed despite a real effort: ALINX's own
product page returns no fetchable content (JS-rendered), a reseller page
403'd, and the community GitHub schematic mirror
([fpgauk/pdf](https://github.com/fpgauk/pdf)) doesn't have an fh1159
folder — it has fh1219, fh1223, fh1224, fh1402, fh7000, fh7621, fh9000,
fh9712, but not fh1159. **No longer an action item** — now that
chip-based HDMI receivers are ruled out (see below), FH1159 is only
useful to us if it turns out to be a direct-GTH passthrough card, and
even then it would need to actually expose a custom-timing-capable path,
which a commercial "plug and play" module isn't obviously designed for.
Not pursuing further unless a native-timing-capable HDMI FMC card
surfaces from somewhere.

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

Given native (direct-GTH) capture is a hard requirement and 4-in+1-out
doesn't fit one eval board's transceiver budget, the recommended path is
**stage it**: start with **AMD ZCU106** for the first real-hardware
milestone specifically *because* its onboard HDMI (3 dedicated GTH,
already wired to real connectors) gives 1 native input + 1 native output
"for free," with zero board-bring-up risk on that pair — the fastest
route to a first native-capture-and-display proof. Add 2 more native
inputs via FMC HPC0 (6 of its 8 GTH lanes) once that's working, reaching
3 native inputs + 1 native output on a single ZCU106 (falls 1 GTH lane
short of the full 4-in goal, per the budget above). The 4th input is a
second board/FMC slot, deferred rather than blocking the rest of Phase 1.

This reverses the earlier Z7-P recommendation (which was made when
chip-based receivers were still on the table and Z7-P's cost/LVDS
advantage mattered more) — ZCU106's onboard HDMI is now a genuine
advantage rather than "3 GTH we might not use," since we need every
native HDMI port we can get and ZCU106's are already built and proven.
Z7-P remains a fine choice for the 2nd-board / 4th-input expansion later
if cost matters more than reusing an identical onboard HDMI reference.

**Not decided, needs your input:** whether to accept the staged
(3-in-then-later-4th) path, or invest upfront in a transceiver-richer
device or custom PCB (options 2/3 above) to hit all 4 native inputs on
one board from the start. The staged path is cheaper and faster to a
working proof; the other two are more "final architecture" but
substantially more expensive/slower.

## Open items before ordering anything

- **Decide the staging question above** — this is the main open decision
  now, more than any specific part number.
- **Decide HDMI-only vs adding/leading with SDI.** The FH1219 find above
  is a real strategic fork, not a footnote: SDI is ~3x more
  transceiver-efficient per channel (chip-based receivers are fine for
  it, unlike HDMI) and is what real Aquilon/E3-class hardware actually
  uses. Staying HDMI-only is simpler (matches the original ask) but SDI
  may be worth it given how much genlock/cable-reach matters to this
  project's goals.
- No purchase has been made. This doc is the basis for a decision, not a
  confirmation of one.
