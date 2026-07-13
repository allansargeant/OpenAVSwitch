# Simulation

Phase 1 logic/simulation track (see [../docs/phase1-plan.md](../docs/phase1-plan.md)).
Proves the capture -> frame-buffer -> crossbar -> output pipeline's CDC and
frame-boundary switching logic, independent of any real board/HDMI PHY.

## Requirements

- [Icarus Verilog](http://iverilog.icarus.com/) (`brew install icarus-verilog`)
- Optionally [GTKWave](https://gtkwave.sourceforge.net/) for waveform viewing

## Run

```
make sim
```

Expect:

```
TEST PASSED: 52 output frames observed, 0 errors, channels_seen=1111 (all 4 exercised)
```

`tb_top.sv` wires 4 asynchronous sim sources (`models/video_source_sim.sv`,
each on its own unrelated clock period) through 4
`frame_buffer_channel` instances into one `output_crossbar` +
`timing_gen`, and drives `channel_select` changes at arbitrary times
(deliberately not aligned to any frame boundary). It self-checks that:

1. no output frame ever mixes pixel data from two different sources
   (would indicate a mid-frame tear),
2. the decoded source always matches the crossbar's own `active_channel`,
3. no X/undefined bits appear in active-video output data, and
4. all requested channels were actually observed on the output (so the
   test isn't trivially passing without exercising the switch).

Sanity-checked by deliberately breaking `output_crossbar`'s frame-boundary
latch (making it update every cycle instead of only at `frame_start`) and
confirming the self-check fails loudly (it does — hundreds of "source
mixed within one output frame" errors) before reverting.
