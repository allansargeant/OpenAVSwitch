# Carrier board (KiCad project)

Status: **real component placement underway.** Design content lives in
[../../docs/carrier-board-spec.md](../../docs/carrier-board-spec.md) —
read that first.

## Scope of this board

**3 fully-independent native HDMI inputs + 1 fully-independent native
HDMI output**, one GTH quad each on the Trenz TE0807 SOM, no cross-quad
clock sharing. The 4th input is deferred to a second TE0807/carrier
board — see carrier-board-spec.md for why.

## Libraries

`libs/` holds real, downloaded component libraries (SnapEDA exports),
not placeholders:

- `libs/symbols/TXS0102DCUR.kicad_sym`, `libs/symbols/SS5-80-3.50-X-D-K-XX.kicad_sym`
- `libs/footprints.pretty/` — matching footprints
- `libs/3dmodels/` — STEP models
- `sym-lib-table` / `fp-lib-table` — project-local library tables (using
  `${KIPRJMOD}` relative paths) wiring the above into the project,
  including name-aliased fp-lib-table entries so the Footprint
  properties baked into each downloaded symbol resolve correctly.

Both downloaded libraries were re-validated through `kicad-cli sch/fp/sym
upgrade` before use, not trusted blind.

**Still needed** (couldn't find pre-made libraries for these — see
carrier-board-spec.md for the part numbers): **Si5341A**, **ESD8040**,
**Amphenol GSD1S211-K1E1-4030**. These need hand-transcription from
datasheets — real, careful work, not done yet.

## What's placed

- `hdmi_in1.kicad_sch`, `hdmi_in2.kicad_sch`, `hdmi_in3.kicad_sch`,
  `hdmi_out.kicad_sch` — each has a TXS0102DCUR (DDC/HPD level
  translator) placed and fully validated: `kicad-cli sch upgrade`
  round-trips clean, `kicad-cli sch erc` across the whole hierarchy
  shows only the expected "pin not connected" warnings (nothing is
  wired to a net yet, which is correct at this stage) — no structural
  errors.
- `som_connector.kicad_sch` — **J1** (Samtec SS5-80-3.50-L-D-K-TR, 160
  pins) placed. This one has a known, real quirk: the part's symbol is
  split into 2 units (80 pins each, one per connector row), and
  `kicad-cli sch upgrade` collapses both placed instances to `(unit 1)`
  during its normalization pass rather than preserving `unit 1` /
  `unit 2` as authored. **Verified this doesn't lose or duplicate any
  pin data** (all 160 pin numbers present, unique, correctly mapped) —
  it's a cosmetic/organizational quirk in how kicad-cli's non-interactive
  upgrade handles multi-unit symbols, not a netlist correctness bug.
  Genuinely couldn't resolve this further without KiCad's interactive
  GUI (which has purpose-built tools for placing subsequent units of a
  multi-unit symbol correctly) — **please open this sheet in KiCad and
  check the unit assignment looks right before J2-J4 get added the same
  way.** J2, J3, J4 aren't placed yet, pending that check.

## Next steps

1. **You**: open `som_connector.kicad_sch` in real KiCad, confirm J1's
   two halves show as distinct units (fix in the GUI if not — should be
   quick there even though it wasn't from text).
2. Replicate J1's placement pattern to J2, J3, J4 once 1 is resolved.
3. Hand-transcribe Si5341A, ESD8040, and the Amphenol HDMI connector
   from their datasheets into new symbol/footprint files.
4. Populate `clocking.kicad_sch`, `hdmi_in*.kicad_sch` (ESD, connector,
   EDID), `hdmi_out.kicad_sch`, and `power.kicad_sch` with the
   transcribed parts.
5. Actually wire nets between placed components — nothing is connected
   yet, only placed.
6. Confirm the GTH allocation at the Vivado pin-planner level once real
   pin assignments start.
