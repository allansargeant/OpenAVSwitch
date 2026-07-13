# Carrier board spec (SOM + custom carrier)

Status: draft, pre-schematic. Captures the SOM choice and the GTH
transceiver budget/mapping — including an unresolved clocking question
that needs to be answered before pin assignments are final.

## SOM choice: Trenz TE0807 (recommended)

**Trenz Electronic TE0807** (e.g. TE0807-03-7DE21-AZ: XCZU7EV-1FBVB900E,
4GB DDR4, 128MB QSPI boot flash), ~$1,367 (Jul 2026, DigiKey/Trenz shop).
Confirmed directly from Trenz's own [TE0807 TRM](https://wiki.trenz-electronic.de/display/PD/TE0807+TRM):

- **All 20 of the chip's high-speed transceivers are wired to the
  module's board-to-board connectors** — 16 GTH (banks 224-227, 4 lanes
  each) + 4 GTR (bank 505) — nothing consumed internally by the module
  itself. This is the whole point of going SOM+carrier: an eval board
  pre-spends transceivers on its own onboard peripherals (PCIe, SFP+,
  etc.); a bare SOM spends none, leaving the full budget for us.
- 4x B2B connectors (J1-J4), "Razor Beam LP Slim Terminal Strip," 0.5mm
  pitch, 160 contacts each (Samtec-class — exact Samtec part number and
  KiCad footprint still needed, see open items).
- Same XCZU7EV chip already used in prior research, so the "native HDMI
  needs direct-GTH" reasoning and 3-GTH-per-port cost from
  hardware-selection.md carries over unchanged.

**Alternative noted, not chosen**: Enclustra Andromeda XZU65 also
supports a ZU7EV variant and markets itself explicitly for
transceiver-heavy video applications, but no pricing was obtainable in
this research pass — worth a quote if Trenz doesn't pan out.

## GTH budget: 15 needed, 16 available — but not that simple

Naive math looks fine: 4 native HDMI in + 1 native HDMI out = 15 GTH
lanes, TE0807 has 16 GTH. **But the 16 GTH lanes aren't 16 independent
slots — they come in 4 fixed quads of 4 lanes each (banks 224, 225, 226,
227), and lanes within a quad normally share a reference clock.**

If every HDMI port needs to run its own genuinely arbitrary, independent
pixel rate (which is the whole point of the native-capture requirement),
each port's 3 TMDS lanes ideally want to come from the *same* quad, so
they share one coherent reference clock. That gives exactly **4 clean
one-port-per-quad slots** (3 of 4 lanes used, 1 spare per quad) — enough
for 4 independently-clocked native ports, not 5. There's no clean 5th
quad for the output.

**This is the top open technical question, not a minor detail**:

- Does the UltraScale+ GTH clocking backbone allow a reference clock (or
  recovered clock) to be routed *across* quads cleanly enough that a 5th
  port could borrow the leftover lane from two different quads and still
  behave coherently? (UG578 territory — needs a real read, not
  assumption, before any pin gets assigned.)
- If not, does the output actually need full independence from every
  input's clock domain, or is there an acceptable design where it
  shares a quad with one input under some constraint? (Tentatively:
  probably not acceptable — the output needs to serve whatever display
  is attached regardless of which input is on-air, so tying its clock to
  one specific input's quad seems wrong, but this deserves real thought,
  not a quick assumption.)
- If neither works cleanly, the honest fallback is: **4 independently-
  clocked native ports in this carrier's first revision** (e.g. 4 inputs,
  with output sharing a quad with one input in a way still TBD, or output
  deferred to a small revision-2 daughter addition) rather than forcing a
  5th port that turns out to glitch under real arbitrary-rate testing.

**Action item before schematic capture starts**: read UG578 (UltraScale
Architecture GTH Transceivers user guide) clocking chapter specifically
for cross-quad reference clock distribution, and settle this before any
GTH pin gets assigned to a connector.

## Provisional GTH allocation (pending the question above)

| Quad (bank) | Lanes | Tentative assignment |
|---|---|---|
| 224 | 4 | HDMI IN 1 (3 lanes) + 1 spare |
| 225 | 4 | HDMI IN 2 (3 lanes) + 1 spare |
| 226 | 4 | HDMI IN 3 (3 lanes) + 1 spare |
| 227 | 4 | HDMI IN 4 (3 lanes) + 1 spare |
| GTR (bank 505) | 4 | Not used for HDMI (see below); reserved/spare |
| HDMI OUT | — | **Unassigned — blocked on the clocking question above** |

GTR transceivers are *not* used for any HDMI port: their typical ~6Gbps
ceiling leaves too little margin over 4K60's ~5.94Gbps-per-lane TMDS
rate. GTH (16.3Gbps-rated) is the safe choice for all video, consistent
with hardware-selection.md.

## Control plane: keep it off the GTH budget

With GTH this tight, the carrier should not spend any on PCIe or other
control-plane links. The Zynq UltraScale+ PS has hardened Gigabit
Ethernet (GEM) controllers that talk to an external PHY over ordinary
RGMII/SGMII I/O — not GTH — so networking/control access costs regular
I/O pins, not transceivers. Recommendation: one external Gigabit
Ethernet PHY on RGMII from the PS, no PCIe on this board rev.

## Not yet designed (real schematic work, not done here)

- HDMI connector-side circuitry per port: AC-coupling caps on the 3 TMDS
  data pairs, ESD protection, 5V-tolerant level shifting for
  HPD/CEC/DDC, EDID emulation (EEPROM or FPGA-driven) per input.
- Reference clock generation: if each of the (up to 4, pending the open
  question) native ports needs an independently-programmable rate, this
  likely means a programmable clock synthesizer (e.g. Si5341/Si5345
  class) per port or per quad, not a fixed oscillator — not selected
  yet.
- Power: TE0807 needs specific input rail(s) per its TRM (not
  transcribed here yet) — carrier needs its own regulation for HDMI
  connector-side logic (3.3V/5V) on top of whatever the module needs.
- Exact Samtec B2B connector part number + KiCad footprint/symbol for
  the 4x160-contact 0.5mm-pitch connectors.
- Explicit **no-HDCP** stance: not implementing HDCP (licensing/legal
  scope, consistent with MiSTer's own position) — protected/encrypted
  HDMI sources will not display. Worth stating plainly in end-user docs
  later, not just here.

## Open items before ordering the SOM or starting schematic capture

- **Resolve the cross-quad clocking question above** — this determines
  whether the carrier can support the full 4-in+1-out native design at
  all, or needs to ship a reduced port count in its first revision.
- Get the exact Samtec B2B connector part number from Trenz (for KiCad
  footprint sourcing).
- Decide the reference clock architecture (how many independently
  programmable clock domains, which synthesizer part).
- No SOM purchase has been made yet. This doc is the basis for a
  decision, not a confirmation of one.
