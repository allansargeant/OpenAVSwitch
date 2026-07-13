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
    independently-clocked HDMI ports (4 inputs each with their own
    synthesizer; output borrows lanes from quads 224/225/226, sharing
    225's reference — see carrier-board-spec.md for the IN2/OUT coupling
    this implies)
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

The GTH cross-quad clocking question that used to block this is now
resolved (see carrier-board-spec.md): confirmed from UG576/UG578 that
UltraScale+ GTH quads can share a reference clock across up to 2
neighboring quads via dedicated `GTNORTHREFCLK`/`GTSOUTHREFCLK` routing,
well within budget for HDMI TMDS's ~5.94Gb/s line rate, and XCZU7EV's
quads 224-227 are confirmed physically sequential/adjacent — so the full
4-in+1-out native design fits on TE0807's 16 GTH lanes (allocation table
in carrier-board-spec.md). What's left before real schematic capture is
component/part selection (connector, clock synthesizer), not an open
architectural question.

## Next steps

1. Get the exact Samtec B2B connector part number from Trenz for
   `som_connector.kicad_sch`'s footprints.
2. Decide the reference clock synthesizer part for `clocking.kicad_sch`,
   accounting for the quad-225/HDMI-OUT reference-clock coupling noted
   in carrier-board-spec.md.
3. Populate `hdmi_in*.kicad_sch` / `hdmi_out.kicad_sch` with actual
   connector + support circuitry once 1-2 are settled.
4. Confirm the GTH allocation at the Vivado pin-planner level once pins
   start getting assigned, as a final sanity check.
