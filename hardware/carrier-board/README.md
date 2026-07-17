# Carrier board (KiCad project)

Status: **all 4 SOM connectors + level translators + clock generator
placed and validated; ESD8040 genuinely blocked; real HDMI connector
part still needed.** Design content lives in
[../../docs/carrier-board-spec.md](../../docs/carrier-board-spec.md) —
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
- `libs/symbols/HDMI_TypeA_Receptacle.kicad_sym` — **hand-built from the
  public HDMI specification's pinout** (manufacturer-independent, so
  high confidence), not tied to a specific manufacturer part. **No
  footprint yet** — see below.
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

**Genuinely blocked, not transcribed: ESD8040.** 5+ fetch attempts
across onsemi.com (403), Mouser/Farnell (timeout, or once returned an
unrelated part's datasheet — ESD8351 — caught before it was used), 
DigiKey's HTML page (410 Gone), and web archive (blocked entirely) all
failed to produce the actual pin table. Not fabricated as a workaround.
Needs the user to source the datasheet directly, or a different ESD part
with an accessible one.

**Correction**: an earlier research pass named "Amphenol
GSD1S211-K1E1-4030" as the HDMI connector. That part number **could not
be verified as real** in this pass — never turned up anywhere. Treat it
as wrong. The `HDMI_TypeA_Receptacle` symbol above uses the public
HDMI pinout instead, sidestepping the need for a specific (possibly
fictional) part number for the *symbol* — but a real manufacturer part
and its real footprint still need picking before layout.

## What's placed

- `hdmi_in1.kicad_sch`, `hdmi_in2.kicad_sch`, `hdmi_in3.kicad_sch`,
  `hdmi_out.kicad_sch` — each has a TXS0102DCUR placed and validated.
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

## Next steps

1. Source the ESD8040 datasheet (or pick an alternative ESD part) and a
   real HDMI connector manufacturer part + footprint.
2. Populate `hdmi_in*.kicad_sch` / `hdmi_out.kicad_sch` with the
   connector, ESD protection, and EDID circuitry once 1 is resolved.
3. Design `power.kicad_sch`'s regulation + power-good sequencing circuit
   (fully specified in carrier-board-spec.md, not drawn yet).
4. Actually wire nets between placed components — nothing is connected
   yet, only placed.
5. Confirm the GTH allocation at the Vivado pin-planner level once real
   pin assignments start.
6. Optional cosmetic cleanup: reposition J2-J4 or resize the paper so
   som_connector.kicad_sch fits visually on one printable page.
