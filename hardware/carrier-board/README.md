# Carrier board (KiCad project)

Status: **all 4 SOM connectors + level translators + clock generator +
power sequencing circuit placed and validated; real HDMI connector part
resolved and placed in all 4 HDMI sheets; TXS0102 level-translator power
pins (VCCA/VCCB/GND) wired to +3V3/GND in all 4 HDMI sheets; ESD
protection switched to a correctly-rated real part (Semtech RClamp0574P)
though its exact pin table is still unsourced.**
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
  HDMI_TypeA_Receptacle connector (J1) placed, plus J1's DDC/HPD-side
  level-translator power pins wired: U1 VCCA/VCCB → `+3V3`, U1 GND →
  `GND` (global labels, coincident with the pin's connection point,
  same label-coincidence technique as `power.kicad_sch`). J1's own
  power pins (PLUS5V, DDC_CEC_GND, SHELL) and all TMDS/DDC/HPD signal
  nets are still unwired — next step.
- `clocking.kicad_sch` — Si5341A placed and validated, single-unit
  symbol so it avoided the multi-unit quirk below entirely.
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
matters later.

## Next steps

1. Source RClamp0574P's actual pin table (part confirmed real and
   correctly rated, just the datasheet itself — the only genuinely
   blocked item left).
2. Wire the TMDS/DDC/HPD signal nets between J1 and U1 (the connector
   is placed, U1's power pins are wired, but the actual level-translated
   DDC/HPD signal path between them is not yet connected), add ESD
   protection once 1 is resolved, and EDID circuitry.
3. Design `power.kicad_sch`'s VCCO regulators themselves (the sequencing
   circuit driving their EN pins is done — see above) once specific
   regulator parts are chosen.
4. Wire the remaining nets between placed components — TMDS/clock pairs
   from J1/clocking to the GTH-facing SOM connector pins are still
   unconnected.
5. Confirm the GTH allocation at the Vivado pin-planner level once real
   pin assignments start.
6. Optional cosmetic cleanup: reposition J2-J4 or resize the paper so
   som_connector.kicad_sch fits visually on one printable page; offset
   the overlapping label pairs in power.kicad_sch for readability.
