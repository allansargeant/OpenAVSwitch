# Carrier board (KiCad project) — not yet started

Status: **KiCad project not created yet.** See why, and what's ready to
go once it is, below. Design content lives in
[../../docs/carrier-board-spec.md](../../docs/carrier-board-spec.md) —
read that first.

## Why there's no .kicad_pro here yet

Two blockers, one tooling, one technical:

1. **KiCad isn't installed on this machine yet.** `brew install --cask
   kicad` needs a one-time interactive `sudo` password prompt (to install
   shared demo files under `/Library/Application Support`), which
   isn't available in a non-interactive session. Run this yourself in a
   real terminal:
   ```
   brew install --cask kicad
   ```
   or download the installer directly from
   [kicad.org/download](https://www.kicad.org/download/macos/) if you'd
   rather not use Homebrew.
2. **The GTH cross-quad clocking question in carrier-board-spec.md is
   still open.** Real schematic capture (actual GTH pin assignments,
   connector pinout) shouldn't start until that's resolved — a project
   built around a wrong assumption there would need its pin mapping
   redone anyway. Not a reason to avoid setting up the project
   structure itself, just a reason not to hand-author schematic files
   blind before either KiCad or that answer exists to validate against.

## Intended structure, once both are unblocked

A hierarchical KiCad project (not one flat schematic), sheets matching
carrier-board-spec.md's blocks:

- `carrier-board.kicad_pro` / `.kicad_sch` (top sheet — just hierarchical
  sheet symbols, no components)
  - `som_connector.kicad_sch` — the 4x Trenz TE0807 B2B connectors
  - `power.kicad_sch` — carrier-side regulation (HDMI connector-side
    3.3V/5V etc.), on top of whatever the module itself needs
  - `clocking.kicad_sch` — reference clock synthesizer(s) for the
    (pending the open question) independently-clocked HDMI ports
  - `hdmi_in1.kicad_sch` … `hdmi_in4.kicad_sch` — one sheet per input:
    connector, AC-coupling, ESD protection, level shifting, EDID EEPROM
  - `hdmi_out.kicad_sch` — output connector + associated circuitry
  - `ethernet.kicad_sch` — Gigabit Ethernet PHY on RGMII from the PS
    (control-plane link, deliberately off the GTH budget)
- `carrier-board.kicad_pcb` — layout, once schematics are captured

## Not done here, and not safe to fake

I didn't hand-author placeholder `.kicad_pro`/`.kicad_sch` files for
this, on purpose: those formats (JSON + S-expression) have version/UUID
fields that need to round-trip cleanly through the actual application,
and I have no way to open or validate them without KiCad installed here.
A file I can't test is worse than no file — it looks done but might
silently fail to open or repair-corrupt on first launch. Once KiCad is
installed (by you, or in a future session where `kicad-cli` is
available), creating this skeleton is a quick, well-defined task.
