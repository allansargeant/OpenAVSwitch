# Carrier board (KiCad project)

Status: **most parts placed, one part genuinely blocked.** Design
content lives in
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
- `som_connector.kicad_sch` — **J1** (Samtec SS5-80-3.50-L-D-K-TR, 160
  pins) placed. Known quirk: the part's symbol is split into 2 units (80
  pins each, one per connector row), and `kicad-cli sch upgrade`
  collapses both placed instances to `(unit 1)` during normalization.
  **Verified this doesn't lose or duplicate any pin data** (all 160
  numbers present, unique, correctly mapped) — cosmetic/organizational,
  not a netlist bug, but couldn't fix it without KiCad's interactive
  GUI. **Please open this sheet in KiCad and check the unit assignment**
  before J2-J4 get added the same way.

Full-hierarchy `kicad-cli sch erc` shows only expected violations
(unconnected pins on placed-but-unwired components, and the known J1
unit quirk above) — no unexplained structural errors anywhere.

## Next steps

1. **You**: check `som_connector.kicad_sch`'s J1 unit assignment in real
   KiCad (see above).
2. Replicate J1's placement pattern to J2, J3, J4 once 1 is resolved.
3. Source the ESD8040 datasheet (or pick an alternative ESD part) and a
   real HDMI connector manufacturer part + footprint.
4. Populate `hdmi_in*.kicad_sch` / `hdmi_out.kicad_sch` with the
   connector, ESD protection, and EDID circuitry once 3 is resolved.
5. Design `power.kicad_sch`'s regulation + power-good sequencing circuit
   (fully specified in carrier-board-spec.md, not drawn yet).
6. Actually wire nets between placed components — nothing is connected
   yet, only placed.
7. Confirm the GTH allocation at the Vivado pin-planner level once real
   pin assignments start.
