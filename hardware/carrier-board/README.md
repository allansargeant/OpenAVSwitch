# Carrier board (KiCad project)

Status: **hierarchical project skeleton created and validated, scope
finalized, no components placed yet.** Design content lives in
[../../docs/carrier-board-spec.md](../../docs/carrier-board-spec.md) —
read that first.

## Scope of this board

**3 fully-independent native HDMI inputs + 1 fully-independent native
HDMI output**, one GTH quad each on the Trenz TE0807 SOM, no cross-quad
clock sharing. The 4th input (for Phase 1's overall 4-in+1-out goal) is
deferred to a second TE0807/carrier board rather than compromised —
see carrier-board-spec.md for why cross-quad sharing doesn't actually
buy a 5th independent port.

## What's here

A hierarchical KiCad 10 project, sheets matching carrier-board-spec.md's
blocks:

- `carrier-board.kicad_pro` / `carrier-board.kicad_sch` — top sheet, just
  hierarchical sheet symbols, no components
  - `som_connector.kicad_sch` — the 4x Trenz TE0807 B2B connectors
    (Samtec SS5-80-3.50-L-D-K-TR, part number confirmed, KiCad footprint
    available from the official library / SnapEDA)
  - `power.kicad_sch` — carrier-side regulation (HDMI connector-side
    3.3V/5V etc.), on top of whatever the module itself needs
  - `clocking.kicad_sch` — one Silicon Labs Si5341A (10-output
    any-frequency clock generator, part selected) feeding all 4 quads'
    reference pins independently, 6 outputs spare
  - `hdmi_in1.kicad_sch` / `hdmi_in2.kicad_sch` / `hdmi_in3.kicad_sch` —
    one sheet per input: connector, AC-coupling, ESD protection, level
    shifting, EDID EEPROM
  - `hdmi_out.kicad_sch` — output connector + associated circuitry
  - `ethernet.kicad_sch` — Gigabit Ethernet PHY on RGMII from the PS
    (control-plane link, deliberately off the GTH budget)
- `carrier-board.kicad_pcb` — not created yet; comes after schematics

Every sheet is currently a stub (title block only, no symbols) — verified
by round-tripping through `kicad-cli sch upgrade` (parses and re-saves
cleanly) and `kicad-cli sch erc` (0 errors, 0 warnings, all 8 sheets
resolve correctly through the hierarchy). Open `carrier-board.kicad_pro`
in KiCad to see the block-diagram-level layout.

## Why no components are placed yet

Scope and part selection are settled — connector, clock synthesizer, and
GTH quad allocation are all decided (carrier-board-spec.md). What
remains is real schematic capture: actual pin assignments, HDMI
connector-side support circuitry (AC-coupling, ESD, level shifting,
EDID), and power rail design. That's genuine circuit design work, not
something to hand-wave into stub files.

## Next steps

1. Confirm the GTH allocation at the Vivado pin-planner level once pins
   start getting assigned, as a final sanity check on the architecture-
   level analysis in carrier-board-spec.md.
2. Populate `som_connector.kicad_sch` with the SS5 connector footprints
   and GTH/LVDS pin assignments.
3. Populate `clocking.kicad_sch` with the Si5341A and its 4 output
   connections to the quads.
4. Populate `hdmi_in*.kicad_sch` / `hdmi_out.kicad_sch` with connector +
   support circuitry (AC-coupling, ESD, level shifting, EDID EEPROM).
5. Design `power.kicad_sch` once TE0807's exact input rail requirements
   are transcribed from its TRM.
