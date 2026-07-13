// Sim-only stand-in for a real HDMI input receiver front-end. Reuses
// rtl/output/timing_gen.sv for the actual timing (it's a generic timing
// generator, not output-specific) and tags each pixel with {channel_id,
// frame_counter} instead of real pixel data, so the testbench can verify
// exactly which source's frame reached the output without needing real
// image data. Deliberately lives under sim/, not rtl/ — this is test
// infrastructure, not part of the real capture pipeline.
module video_source_sim #(
    parameter int CHANNEL_ID  = 0,
    parameter int H_ACTIVE    = 64,
    parameter int H_BLANK     = 16,
    parameter int V_ACTIVE    = 48,
    parameter int V_BLANK     = 8,
    parameter int DATA_WIDTH  = 16,
    parameter int CHAN_BITS   = 4
) (
    input logic clk,
    input logic rst_n,

    output logic                  de,
    output logic                  frame_start,
    output logic [DATA_WIDTH-1:0] data
);

  logic [$clog2(H_ACTIVE * V_ACTIVE)-1:0] addr_unused;
  logic [DATA_WIDTH-CHAN_BITS-1:0] frame_counter;

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
      .addr       (addr_unused)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) frame_counter <= '0;
    else if (frame_start) frame_counter <= frame_counter + 1'b1;
  end

  assign data = {CHANNEL_ID[CHAN_BITS-1:0], frame_counter};

endmodule
