# Simulation

Phase 1 logic/simulation track (see [../docs/phase1-plan.md](../docs/phase1-plan.md)).
Proves the capture -> frame-buffer -> scale -> crossbar -> output
pipeline's CDC, scaling, and frame-boundary switching logic, independent
of any real board/HDMI PHY.

## Requirements

- [Icarus Verilog](http://iverilog.icarus.com/) (`brew install icarus-verilog`)
- Optionally [GTKWave](https://gtkwave.sourceforge.net/) for waveform viewing

## Run

```
make sim
```

Expect:

```
TEST PASSED: 113 output frames observed, 0 errors, channels_seen=1111 (all 4 exercised)
```

`tb_top.sv` wires 4 asynchronous sim sources (`models/video_source_sim.sv`,
each on its own unrelated clock period, and each at its own native
resolution: one matches the output, one 2x upscales, one 2x downscales,
one uses a non-integer 4/3 ratio) through `frame_buffer_channel` ->
`nn_scaler` -> `output_crossbar` -> `timing_gen`, and drives
`channel_select` changes at arbitrary times (deliberately not aligned to
any frame boundary). It self-checks that:

1. no output frame ever mixes pixel data from two different sources
   (would indicate a mid-frame tear),
2. the decoded source always matches the crossbar's own `active_channel`,
3. no X/undefined bits appear in active-video output data,
4. all requested channels were actually observed on the output (so the
   test isn't trivially passing without exercising the switch), and
5. the decoded source (x, y) at every output pixel matches an
   independently-written nearest-neighbor reference model — i.e. the
   scaler is sampling the geometrically correct source pixel, not just
   "some" pixel from the right channel.

Sanity-checked by deliberately breaking things and confirming the
self-check fails loudly before reverting:
`output_crossbar`'s frame-boundary latch (updating every cycle instead of
only at `frame_start`) → hundreds of "source mixed within one output
frame" errors; `nn_scaler`'s address math (swapping x/y) → hundreds of
"scaler mismatch" errors.
