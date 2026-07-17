# Carrier board (KiCad project)

Status: **all 4 SOM connectors + level translators + clock generator +
power sequencing circuit placed and validated; real HDMI connector part
resolved; ESD protection switched to a correctly-rated real part
(Semtech RClamp0574P) though its exact pin table is still unsourced.**
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

1. Source RClamp0574P's actual pin table (part confirmed real and
   correctly rated, just the datasheet itself — the only genuinely
   blocked item left).
2. Populate `hdmi_in*.kicad_sch` / `hdmi_out.kicad_sch` with the (now
   resolved) HDMI connector, ESD protection once 1 is resolved, and EDID
   circuitry.
3. Design `power.kicad_sch`'s VCCO regulators themselves (the sequencing
   circuit driving their EN pins is done — see above) once specific
   regulator parts are chosen.
4. Actually wire nets between placed components — nothing is connected
   across sheets yet, only placed/self-contained per sheet.
5. Confirm the GTH allocation at the Vivado pin-planner level once real
   pin assignments start.
6. Optional cosmetic cleanup: reposition J2-J4 or resize the paper so
   som_connector.kicad_sch fits visually on one printable page; offset
   the overlapping label pairs in power.kicad_sch for readability.
