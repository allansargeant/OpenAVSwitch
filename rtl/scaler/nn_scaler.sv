// Per-channel nearest-neighbor scaler: maps an output-space coordinate
// (dst_x, dst_y) to the flat address of the nearest source pixel in a
// channel whose native resolution (SRC_W x SRC_H) may differ from the
// output's (DST_W x DST_H). Purely combinational — this is address
// translation, not a memory access; it feeds straight into a
// frame_buffer_channel's rd_addr port (see docs/architecture.md's "scale
// stage" and docs/phase1-plan.md).
//
// Fixed-point ratio (Q.FRAC_BITS), computed once at elaboration time since
// SRC/DST dimensions are compile-time parameters here. Uses a per-pixel
// multiply (dst_x * step) rather than a running accumulator — simpler to
// verify and fine at Phase 1's scale, but a real high-resolution
// implementation would likely replace the multiply with an
// accumulator that adds `step` once per pixel, avoiding a multiplier in
// the per-pixel critical path.
//
// Nearest-neighbor only for now; bilinear (Phase 1 stretch goal / Phase 2)
// would need this to also emit fractional weights and read up to 4
// neighboring source pixels instead of 1.
module nn_scaler #(
    parameter int SRC_W     = 64,
    parameter int SRC_H     = 48,
    parameter int DST_W     = 64,
    parameter int DST_H     = 48,
    parameter int FRAC_BITS = 16
) (
    input logic [$clog2(DST_W)-1:0] dst_x,
    input logic [$clog2(DST_H)-1:0] dst_y,

    output logic [$clog2(SRC_W * SRC_H)-1:0] src_addr
);

  localparam int XStep = (SRC_W << FRAC_BITS) / DST_W;
  localparam int YStep = (SRC_H << FRAC_BITS) / DST_H;

  logic [31:0] src_x_raw, src_y_raw;
  logic [$clog2(SRC_W)-1:0] src_x;
  logic [$clog2(SRC_H)-1:0] src_y;

  assign src_x_raw = (32'(dst_x) * XStep) >> FRAC_BITS;
  assign src_y_raw = (32'(dst_y) * YStep) >> FRAC_BITS;

  // Defensive clamp: guards against any rounding edge case producing an
  // out-of-range address (e.g. the last destination column mapping to
  // exactly SRC_W due to truncation) rather than trusting the arithmetic
  // never overshoots.
  assign src_x = (src_x_raw >= SRC_W) ? (SRC_W - 1) : src_x_raw[$clog2(SRC_W)-1:0];
  assign src_y = (src_y_raw >= SRC_H) ? (SRC_H - 1) : src_y_raw[$clog2(SRC_H)-1:0];

  assign src_addr = src_y * SRC_W + src_x;

endmodule
