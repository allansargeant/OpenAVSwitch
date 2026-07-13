// Sim-only stand-in for a real HDMI input receiver front-end. Reuses
// rtl/output/timing_gen.sv for the actual timing (it's a generic timing
// generator, not output-specific) and tags each pixel with
// {channel_id, y, x} instead of real pixel data. Encoding position (not
// just a per-frame constant) is what lets the testbench verify the scaler
// produced the geometrically correct sample, not just that switching
// didn't tear. Deliberately lives under sim/, not rtl/ — this is test
// infrastructure, not part of the real capture pipeline.
module video_source_sim #(
    parameter int CHANNEL_ID = 0,
    parameter int H_ACTIVE   = 64,
    parameter int H_BLANK    = 16,
    parameter int V_ACTIVE   = 48,
    parameter int V_BLANK    = 8,
    parameter int DATA_WIDTH = 16,
    parameter int CHAN_BITS  = 4,
    parameter int X_BITS     = 6,
    parameter int Y_BITS     = 6
) (
    input logic clk,
    input logic rst_n,

    output logic                  de,
    output logic                  frame_start,
    output logic [DATA_WIDTH-1:0] data
);

  logic [$clog2(H_ACTIVE)-1:0] x;
  logic [$clog2(V_ACTIVE)-1:0] y;

  timing_gen #(
      .H_ACTIVE(H_ACTIVE),
      .H_BLANK (H_BLANK),
      .V_ACTIVE(V_ACTIVE),
      .V_BLANK (V_BLANK)
  ) u_timing (
      .clk        (clk),
      .rst_n      (rst_n),
      .de         (de),
      .frame_start(frame_start),
      .x          (x),
      .y          (y)
  );

  // CHAN_BITS + Y_BITS + X_BITS must equal DATA_WIDTH, and X_BITS/Y_BITS
  // must be wide enough for this channel's own H_ACTIVE/V_ACTIVE — the
  // testbench picks widths that cover the largest resolution in use across
  // all channels, so smaller channels just carry unused leading zeros.
  assign data = {CHANNEL_ID[CHAN_BITS-1:0], Y_BITS'(y), X_BITS'(x)};

endmodule
