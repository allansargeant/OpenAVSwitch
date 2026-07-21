# Carrier board (KiCad project)

Status: **all 4 SOM connectors + level translators + clock generator +
power sequencing circuit placed and validated; real HDMI connector part
resolved and placed in all 4 HDMI sheets; TXS0102 level-translator power
pins (VCCA/VCCB/GND) wired to +3V3/GND, the DDC (SCL/SDA) signal path
from the HDMI connector through the level translator to a
per-sheet-unique 3V3-side net wired, and HPD wired through a dedicated
open-drain N-MOSFET pulldown (2N7002), in all 4 HDMI sheets; exact GTH
B2B pin assignments resolved from the primary TE0807 TRM; Si5341A's 4
needed reference clock outputs wired to the SOM connector; ESD
protection switched to TI TPD1E04U04 (real, fully verified, unlike the
still-blocked Semtech RClamp0574P); all 4 TMDS lines (D0/D1/D2 + CLK)
wired end-to-end from connector through ESD protection to the exact SOM
connector B2B pins in all 4 HDMI sheets — TMDS_CLK routes to each
quad's spare 4th GTH lane rather than the reference clock pins, a
question resolved via AMD's own CDR tracking-range spec, see
carrier-board-spec.md; decoupling capacitors added for TXS0102
(VCCA/VCCB) and Si5341A (all 14 VDD/VDDA/VDDOx pins) — see below.**

**Tooling change (2026-07-21): this project now edits `.kicad_sch` files
exclusively through Konnect's MCP tools**, not hand-authored
S-expression scripts. Konnect provides a validated schematic-editing
API (`add_schematic_component`, `connect_pins`, `get_component_nets`,
etc.) instead of text-editing the KiCad file format directly — safer
in general, but it has its own real quirks, documented below since
they cost real debugging time to find.
Design content lives
in [../../docs/carrier-board-spec.md](../../docs/carrier-board-spec.md) —
read that first.

## Scope of this board

**3 fully-independent native HDMI inputs + 1 fully-independent native
HDMI output**, one GTH quad each on the Trenz TE0807 SOM, no cross-quad
clock sharing. The 4th input is deferred to a second TE0807/carrier
board — see carrier-board-spec.md for why.

## Libraries

`libs/` holds real component libraries — some downloaded, some
hand-transcribed from primary datasheets, none placeholders:

- `libs/symbols/TXS0102DCUR.kicad_sym`, `SS5-80-3.50-X-D-K-XX.kicad_sym`
  — downloaded from SnapEDA.
- `libs/symbols/Si5341A-B-GM.kicad_sym` — **hand-transcribed** from
  Silicon Labs' primary Si5341/40 Data Sheet (Table 17), all 64 QFN
  pins, cross-checked to sum to exactly 64 with no gaps. Footprint
  matched to KiCad's own standard `QFN-64-1EP_9x9mm_P0.5mm_EP5.2x5.2mm`
  (verified against the datasheet's Table 18 dimensions, copied in from
  the local KiCad install's official library).
- `libs/symbols/TPD1E04U04.kicad_sym` — TI single-channel HDMI 2.0-rated
  ESD diode, hand-authored directly from TI's own datasheet (SLVSDG4B):
  2 pins (1=IO, 2=GND), package X1SON/DPY (JEDEC DPY0002A). Chosen over
  the still-blocked Semtech RClamp0574P — see carrier-board-spec.md's
  ESD protection section for the full story (RClamp0574P's 6th+ failed
  attempt turned up a wrong-part PDF, caught via title metadata). One
  instance needed per single-ended line (8 per HDMI port), not 4 lines
  per package like RClamp0574P — more parts, but every one of them is
  trivial and the datasheet (including the mechanical/land-pattern
  drawing) was actually obtainable. Footprint hand-built from the same
  datasheet's land pattern.
- `libs/symbols/2N7002.kicad_sym` — generic N-MOSFET body copied from
  KiCad's own `Device:Q_NMOS`, pin **numbers** remapped from the
  generic symbol's letter placeholders (D/G/S) to the real SOT-23
  physical pinout (1=G, 2=S, 3=D), cross-checked against 4 independent
  manufacturer datasheets (Nexperia, Microchip, ON Semi, ST) via live
  web search, all in agreement. Footprint: KiCad's own bundled
  `Package_TO_SOT_SMD.pretty/SOT-23.kicad_mod`, copied in unmodified.
  Used as the HPD open-drain pulldown (see below).
- `libs/symbols/HDMI_TypeA_Receptacle.kicad_sym` — pinout hand-built from
  the public HDMI specification (manufacturer-independent, high
  confidence), **footprint now resolved**: Amphenol ICC (FCI)
  10029449-001RLF (confirmed in stock on DigiKey), footprint copied from
  KiCad's own `Connector_Video.pretty` library, pad names (1-19 + `SH`)
  cross-checked against the symbol's pins.
- `libs/footprints.pretty/` — matching footprints; `libs/3dmodels/` —
  STEP models where available.
- `sym-lib-table` / `fp-lib-table` — project-local library tables.

Every symbol/footprint (downloaded or transcribed) was validated through
`kicad-cli sym/fp upgrade` before use, not trusted blind.

**Important validation note, learned the hard way**: `kicad-cli sch
upgrade` is safe for single-unit symbols but **actively corrupts
multi-unit symbol instances** (it collapsed both units of a 2-unit
connector to `unit 1` and, worse, ballooned each instance from 80 to all
160 pins — a real bug, not cosmetic). Confirmed by regenerating from
scratch and checking pin data *before* running `upgrade`: correct (80
pins/unit) pre-upgrade, corrupted (160 pins/unit, `different_unit_net`
ERC errors) post-upgrade. **Fix: never run `sch upgrade` on files with
multi-unit symbol instances — validate with `sch erc` alone instead**,
which is read-only and reports correctly. `som_connector.kicad_sch` was
regenerated clean and is validated via `sch erc` only, `sch upgrade` is
never run on it. This was previously (wrongly) flagged as needing a
GUI check — it doesn't; the underlying data was always fine once you
know not to run the corrupting command.

**ESD8040 → switched to Semtech RClamp0574P, still not schematic-ready.**
ESD8040 stayed blocked (5+ fetch attempts across onsemi.com 403,
Mouser/Farnell timeouts or a wrong-document PDF caught before use,
DigiKey 410 Gone, web archive blocked entirely). RClamp0574P is a real
improvement: confirmed directly from Semtech's own product page as
explicitly HDMI 2.0-rated (ESD8040's 4K60 fitness was only ever
inferred, never stated outright). Its exact pin table still didn't
surface though — not fabricated, needs sourcing before use in a
schematic. Also checked TI TPD12S016 (well-documented) and ruled it out:
confirmed HDMI 1.4-only in its own datasheet.

**Resolved**: an earlier research pass named "Amphenol
GSD1S211-K1E1-4030" as the HDMI connector, which never verified as real.
Replaced with Amphenol ICC (FCI) 10029449-001RLF, cross-verified on
DigiKey and matched against KiCad's own footprint library — see above.

## What's placed

- `hdmi_in1.kicad_sch`, `hdmi_in2.kicad_sch`, `hdmi_in3.kicad_sch`,
  `hdmi_out.kicad_sch` — each has a TXS0102DCUR (U1) and the real
  HDMI_TypeA_Receptacle connector (J1) placed. U1's power pins are
  wired: VCCA/VCCB → `+3V3`, GND → `GND` (global labels, coincident
  with the pin's connection point, same label-coincidence technique as
  `power.kicad_sch`). The DDC signal path is wired end-to-end on the
  5V side: J1 pin 15 (SCL) and pin 16 (SDA) connect via real wires to
  U1's A-side pins A1/A2; U1's B-side pins B1/B2 (3.3V side) connect to
  per-sheet-unique global labels (`HDMI_IN1_SCL_3V3`/`_SDA_3V3`,
  `HDMI_IN2_...`, etc — deliberately **not** the same net name across
  sheets, since each HDMI port's DDC bus must stay electrically
  independent) ready to extend to the SOM connector's I2C GPIO pins
  once those are pin-planned. **HPD is now wired too**: J1 pin 19
  (HPD) connects via a real wire to Q1 (2N7002 N-MOSFET) acting as an
  open-drain pulldown — Drain to HPD, Source to `GND`, Gate to a
  per-sheet-unique global label (`HDMI_IN1_HPD_CTL_3V3` etc). No
  pull-up is placed on our side by design: the HDMI *source* provides
  the 5V HPD pull-up per spec, so the sink only needs to pull low when
  not ready. This resolves the "HPD: double-duty or separate GPIO"
  open question from carrier-board-spec.md in favor of the separate-
  GPIO option, since both TXS0102 channels are now committed to DDC.
  **All 4 TMDS lines (D0/D1/D2 + CLK, P+N) are now wired**: each goes
  from J1 through its own TPD1E04U04 ESD diode (shunt to `GND`) to a
  global label matching the exact SOM connector B2B pin resolved from
  the TE0807 TRM (`IN1_TMDS_D0_P`, `IN1_TMDS_CLK_P` etc — see
  som_connector.kicad_sch). TMDS_CLK goes to each quad's "spare" 4th
  GTH lane (same pattern as the data lines) rather than to the
  reference clock pins — see carrier-board-spec.md's "TMDS_CLK
  routing" section for why (Si5341A stays as the reference; AMD's own
  CDR tracking-range spec, ±1250ppm below 6.6Gb/s, confirmed the
  simpler wiring is sound). J1's own power pins (PLUS5V, DDC_CEC_GND,
  SHELL) are still unwired.
- `clocking.kicad_sch` — Si5341A placed and validated, single-unit
  symbol so it avoided the multi-unit quirk below entirely. 4 of its 10
  output pairs (OUT0-OUT3) are now wired via global labels
  (`REFCLK_IN1_P/N` etc) straight to the exact B2B connector pins each
  GTH quad's carrier-reachable reference clock input lands on (per the
  TE0807 TRM Table 6 pin table in carrier-board-spec.md) — `J3` pins
  62/60 (IN1), 67/65 (IN2), 61/59 (OUT), and `J2` pins 22/24 (IN3).
  6 outputs remain spare.
- `som_connector.kicad_sch` — **J1, J2, J3, J4** all placed (Samtec
  SS5-80-3.50-L-D-K-TR x4, 160 pins each, correctly split 80/80 across
  each connector's 2 units). Verified clean via `sch erc` (see note
  above — do not run `sch upgrade` on this file). One minor cosmetic
  item, not a correctness issue: J2/J3/J4 are positioned beyond a single
  A4 page's visible bounds (each 80-pin column is ~200mm tall, so 4
  stacked connectors don't fit one page) — fine for ERC/netlist, but
  worth spacing out differently or moving to a larger paper size for
  anyone reading this visually in the GUI.

Full-hierarchy `kicad-cli sch erc` shows only expected violations
(unconnected pins on placed-but-unwired components) — no unexplained
structural errors anywhere, and no `different_unit_net` errors now that
the corrupting `upgrade` step is avoided.

**Symbol-placement gotcha, learned the hard way while wiring TXS0102
power pins**: a symbol's local pin coordinates (from its `.kicad_sym`,
authored with Y increasing *upward*) do **not** simply add to the
instance's placement offset. At `(at BASE_X BASE_Y 0)` with no mirror,
the correct transform is `global = (BASE_X + local_x, BASE_Y -
local_y)` — KiCad flips local Y because the sheet's coordinate system
increases *downward*. Getting the sign wrong doesn't fail loudly: two
of the three power-pin labels (`GND` and the `+3V3` meant for VCCB)
landed exactly on *each other's* real pin coordinates by coincidence
(their local Y offsets are each other's negation), silently swapping
which net each pin joined, while the third (`+3V3` for VCCA) landed on
empty space and just failed to connect. Caught by comparing each ERC
violation's reported pixel/mm `pos` against the intended pin, not by
any explicit tool error. Fixed by using the correct transform above;
verified via ERC and by checking the reported violation coordinates
match the real pin location for every power pin, not just for the
name that happens to be missing.

**Insertion-marker gotcha, hit while placing Q1 (2N7002)**: a script
that inserts a new `lib_symbols` entry by searching for a fixed text
marker (e.g. "right after the TXS0102DCUR lib entry closes") is only
safe as long as nothing else changes what follows that marker. Once
the HDMI connector and DDC/power wiring tasks changed each sheet's
component-instance ordering, the *same* marker text coincidentally
matched the boundary between two placed *instances* (J1 then U1)
instead of the `lib_symbols` block's own closing paren — inserting a
whole symbol definition into the placed-components section, which
KiCad correctly refused to load ("Failed to load schematic"). Fixed
by finding `lib_symbols`'s closing paren via brace-depth parsing from
its own opening keyword, not by pattern-matching neighboring content.
Prefer this for any future `lib_symbols` insertion. Also hit a plain
grid-alignment slip in the same pass (chose `Q1`'s Y placement as a
round number, 160.0, which isn't a multiple of the 1.27mm grid) —
caught by the `endpoint_off_grid` ERC violation, fixed by snapping to
the nearest 1.27 multiple (160.02).

**Known `kicad-cli sch erc` engine quirk, not a wiring defect**: after
the power-pin fix, the ERC report still flags `HDMI Input 1`'s U1
VCCA and GND pins as `power_pin_not_driven`, while byte-for-byte
identical wiring (confirmed via sorted diff) in `HDMI Input 2`/`HDMI
Input 3`/`HDMI Output` reports clean. Isolated by swapping which
physical file the "HDMI Input 1" sheet *symbol* loads (via its
`Sheetfile` property) with `HDMI Input 2`'s file — the false positive
stayed with the **sheet slot**, not the file content, proving it's a
traversal-order artifact in kicad-cli's ERC engine (this is the first
sheet, in hierarchy traversal order, to introduce the `GND`/`+3V3`
global-label nets; `power.kicad_sch`, which also uses them, is
traversed later) and not a real connectivity problem. Safe to ignore;
re-check in the KiCad GUI's own ERC before trusting either way if this
matters later. The same signature reappeared, now across *all four*
HDMI sheets (each pairing that sheet's `TMDS_CLK_N` with an unrelated
`TMDS_D*` net) after adding decoupling capacitors elsewhere in the
project — re-verified with `trace_from_point` at both label
coordinates in one affected sheet, confirming each sits on its own
distinct wire with no shared point. Same tool-level false positive,
just triggered more broadly now; not re-run through the full sheet-
swap test a second time since the underlying signature and cause are
already established.

## Decoupling capacitors (added via Konnect, 2026-07-21)

Ran Konnect's `design_review`/`audit_decoupling` tools for the first
time on this project — found a real, previously-missed gap: **no
decoupling capacitors existed anywhere in the design**, on either
TXS0102 (VCCA/VCCB) or Si5341A (14 power pins: VDDA, 3×VDD,
VDDO0-9). Fixed:

- **TXS0102** (all 4 HDMI sheets): C1 (VCCA) and C2 (VCCB), 100nF,
  each wired directly to its VCC pin and to `GND`.
- **Si5341A** (`clocking.kicad_sch`): C3-C16, 100nF, one per VDD-family
  pin (VDDA, VDD×3, VDDO0-9), each wired the same way.

TXS0102's caps are done in **all 4 HDMI sheets** (hdmi_in1-3,
hdmi_out), not just hdmi_in1 — same C1/C2 pattern, same verified
approach, replicated once the technique was proven correct.

**These decoupling caps still show `power_pin_not_driven` in ERC, and
that's correct, not a bug**: a capacitor doesn't power a chip, it only
filters noise on a rail that something else must actually drive. No
regulator or supply source feeds `+3V3` (TXS0102's rail) or Si5341A's
VDD-family pins anywhere in this design yet — that's the pre-existing,
already-documented "VCCO regulator" open item below, not something
this pass was meant to fix or something it made worse.

**Real Konnect tool quirks hit while doing this, worth knowing before
repeating this kind of work**:

1. **`connect_pins` between two pins at the exact same coordinate
   writes a zero-length wire that doesn't register in net tracing.**
   Placing a cap so its pin lands precisely on the IC pin (the
   "obvious" way to do it) silently produces a broken connection —
   `get_component_nets` reports the IC pin's net as `null` afterward.
   Fix: always place the cap with a small deliberate offset (this
   project used 1.27mm) so `connect_pins` has to draw a real,
   positive-length wire.
2. **A net with no label anywhere on it reports `net: null` from
   `get_component_nets`/`get_pin_connections`, even when the wire
   connection is completely correct.** This looks identical to the
   zero-length-wire bug above but isn't one — `trace_from_point` at
   the exact pin coordinate is the reliable way to tell them apart: it
   shows the actual wire geometry regardless of whether a label (and
   therefore a net *name*) exists.
3. **`move_schematic_component` does not adjust connected wires** (it
   says so in its own description — read tool descriptions before
   using them, not after). Moving a component after wiring it orphans
   every wire/label that pointed at its old pin locations.
4. **`delete_schematic_net_label` matches by `(net, x, y)` only, with
   no way to disambiguate by UUID.** If an unrelated pre-existing
   label happens to share the exact coordinate of one you're trying to
   remove — which happens often here, since decoupling caps get placed
   right next to existing power pins — it deletes whichever one
   matches first. This genuinely deleted two legitimate, already-
   working `+3V3` labels from Task 32 during this pass; caught only by
   re-running `get_component_nets` afterward and noticing VCCA/VCCB
   had gone from `"+3V3"` to `null`, then fixed by re-adding the exact
   same labels. **Always call `list_schematic_labels` and inspect
   before deleting by coordinate**, don't assume the coordinate is
   uniquely yours.
5. **`batch_connect_to_net` always creates a *local* `net_label`, with
   no way to request a `global_label`** (unlike the single-item
   `connect_to_net`/`add_schematic_net_label`, which both take a
   `label_type` parameter). Since this project's convention is global
   labels everywhere, batch-adding GND connections silently introduced
   local labels next to existing global ones — harmless electrically
   in most cases, but triggered a real `same_local_global_label` ERC
   warning in `hdmi_in1.kicad_sch` where a global `GND` already
   existed. Fixed by deleting the local labels and re-adding them
   individually with `label_type: "global_label"`. If sheet-wide label
   consistency matters, don't use the batch tool for labels that need
   to be global.
6. **A rapid sequence of failed `delete_schematic_net_label` calls
   (13 calls, each erroring "No label named GND") left
   `clocking.kicad_sch` truncated at EOF** — a real file corruption,
   caught immediately because every subsequent Konnect call on that
   file returned a parse error, and by `git diff --stat` showing 1658
   deletions had silently landed despite no successful delete having
   been logged. Recovered via `git checkout` since nothing was
   committed yet. Cause not fully diagnosed (possibly a bug in how
   that tool handles a "not found" case), but the practical lesson:
   **commit or at least sanity-check file validity after any batch of
   delete-by-coordinate calls**, and know that `git checkout` is the
   reliable escape hatch if a Konnect call ever corrupts a file — this
   project is git-tracked specifically so that's always available.

## Next steps

1. RClamp0574P is no longer needed (superseded by TPD1E04U04 for TMDS);
   an ordinary DDC/HPD/CEC-grade ESD array (e.g. SM712-class) is still
   unplaced but is low-priority/low-risk.
2. EDID circuitry (soft I2C slave over the now-wired DDC bus) — this is
   firmware/RTL work, not a schematic task.
3. Design `power.kicad_sch`'s VCCO regulators themselves (the sequencing
   circuit driving their EN pins is done — see above) once specific
   regulator parts are chosen — blocked on two undecided upstream items,
   not just a missing datasheet: the exact per-bank I/O voltage (needs
   the FPGA-side I/O standard decided) and the carrier's own input power
   source (voltage/connector, never specified anywhere in this project).
4. Route the DDC 3V3-side nets (`HDMI_IN1_SCL_3V3` etc, currently
   single-pin nets by design — see the `isolated_pin_label` ERC warnings,
   expected and benign until this is done) on to the GTH-facing SOM
   connector pins, once real GPIO pin assignments exist for them (unlike
   TMDS, these are ordinary GPIO and weren't in the TE0807's MGT table —
   the TRM points to a separate, fuller "Pin-out table" resource on
   Trenz's own site that wasn't tracked down in this pass, not fabricated,
   needs a dedicated look).
5. Confirm the GTH allocation at the Vivado pin-planner level once real
   pin assignments start (sanity-check only at this point — the B2B pin
   numbers are already resolved from the primary TRM).
6. Optional cosmetic cleanup: reposition J2-J4 or resize the paper so
   som_connector.kicad_sch fits visually on one printable page; offset
   the overlapping label pairs in power.kicad_sch for readability.
