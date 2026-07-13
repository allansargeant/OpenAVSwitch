# Carrier board (KiCad project)

Status: **hierarchical project skeleton created and validated, no
components placed yet.** Design content lives in
[../../docs/carrier-board-spec.md](../../docs/carrier-board-spec.md) —
read that first.

## What's here

A hierarchical KiCad 10 project, sheets matching carrier-board-spec.md's
blocks:

- `carrier-board.kicad_pro` / `carrier-board.kicad_sch` — top sheet, just
  hierarchical sheet symbols (3x3 grid), no components
  - `som_connector.kicad_sch` — the 4x Trenz TE0807 B2B connectors
  - `power.kicad_sch` — carrier-side regulation (HDMI connector-side
    3.3V/5V etc.), on top of whatever the module itself needs
  - `clocking.kicad_sch` — reference clock synthesizer(s) for the
    (pending the open question below) independently-clocked HDMI ports
  - `hdmi_in1.kicad_sch` … `hdmi_in4.kicad_sch` — one sheet per input:
    connector, AC-coupling, ESD protection, level shifting, EDID EEPROM
  - `hdmi_out.kicad_sch` — output connector + associated circuitry
  - `ethernet.kicad_sch` — Gigabit Ethernet PHY on RGMII from the PS
    (control-plane link, deliberately off the GTH budget)
- `carrier-board.kicad_pcb` — not created yet; comes after schematics

Every sheet is currently a stub (title block only, no symbols) — verified
by round-tripping through `kicad-cli sch upgrade` (parses and re-saves
cleanly) and `kicad-cli sch erc` (0 errors, 0 warnings, all 9 sheets
resolve correctly through the hierarchy). Open `carrier-board.kicad_pro`
in KiCad to see the block-diagram-level layout.

## Why no components are placed yet

The GTH cross-quad clocking question in carrier-board-spec.md is still
open: whether the UltraScale+ GTH clocking backbone (UG578) allows a
coherent 5th independently-clocked HDMI port by borrowing lanes across
quads, or whether this carrier's first revision ships with 4 native
ports and defers the 5th. Real schematic capture — actual GTH pin
assignments in `som_connector.kicad_sch`, connector pinouts in the
`hdmi_*.kicad_sch` sheets — shouldn't start until that's resolved, since
it directly determines the pin mapping. Nothing about the sheet
structure itself depends on the answer, which is why the skeleton was
safe to build now.

## Next steps

1. Resolve the cross-quad clocking question (UG578 research).
2. Get the exact Samtec B2B connector part number from Trenz for
   `som_connector.kicad_sch`'s footprints.
3. Decide the reference clock synthesizer part for `clocking.kicad_sch`.
4. Populate `hdmi_in*.kicad_sch` / `hdmi_out.kicad_sch` with actual
   connector + support circuitry once 1-3 are settled.
