# I/O daughtercard spec (draft v0.1 / RFC)

Status: draft. Not needed until Phase 3, but sketched early so Phase 1
choices (connector, clocking) don't accidentally paint us into a corner.
Everything here is open to revision once Phase 1/3 hit real constraints.

## Physical / electrical

- Connector: **FMC or FMC+ (VITA 57.1 / 57.4)**. Reuses an existing
  mature ecosystem (commercial HDMI/SDI/DP mezzanine cards, defined
  sideband I2C, defined power rails) instead of a custom connector.
- Card identification: I2C EEPROM on-card (as VITA 57.1 already defines)
  so the host can auto-detect card type/capabilities at boot/hot-plug.
- Power: define a per-slot power ceiling once we know real card draw
  (HDMI receiver/EDID chips are low power; some SDI or fiber cards are
  not) — placeholder, not yet specified.

## Clock / genlock distribution

This is the part that actually matters for seamless switching to work
across cards, not just within one board's fabric:

- A reference clock (or reference frame-sync pulse) is distributed from
  the host/control card to every I/O card slot.
- Cards may free-run with their own local PLL for receiver/transmitter
  timing, but must cross into the shared reference domain (via
  FIFO/clock-domain-crossing into the frame buffer) before data reaches
  the shared memory pool — the compositor should never have to reason
  about a card's local clock domain.
- This needs to be validated in Phase 1 even though Phase 1 has no
  daughtercards yet, because Phase 1's 4 HDMI inputs are already 4
  independent, unsynchronized clock domains that all have to land in a
  shared DDR4 pool cleanly. Whatever CDC approach works there is the
  starting point for the cross-card version.

## Data interface

- Pixel data: high-speed serial lanes (MGT) per card, routed to the host
  FPGA for capture-stage processing, OR already-deserialized data if the
  card carries its own front-end logic (e.g. an SDI card doing its own
  SMPTE 424M deserialization on-card).
- Control/status sideband: I2C or SPI, for EDID emulation, hot-plug
  detect, format-detection registers, card health/status.

## Open items (not yet decided)

- Exact FMC pin mapping / lane assignment per card type.
- Per-slot power budget numbers.
- Mechanical card size and faceplate, once Phase 4's chassis design
  starts — FMC alone doesn't define a rack-mount card outline.
- Hot-plug behavior (can a card be inserted/removed live without
  disturbing other slots?).
