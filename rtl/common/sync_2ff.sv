// Generic multi-bit 2-flop synchronizer.
//
// Only safe for signals that change rarely relative to dst_clk and where
// the source guarantees the bits arrive already-coherent (e.g. a Gray-coded
// counter, or a single-bit-at-a-time change, or a value that's stable for
// many dst_clk cycles before being sampled again). It does NOT make an
// arbitrary multi-bit bus atomic across a clock domain — see
// frame_buffer_channel.sv for how this is actually used safely (the value
// being synchronized only changes at most once per source frame, and is
// held stable for a full frame time before changing again).
module sync_2ff #(
    parameter int WIDTH = 1
) (
    input  logic             dst_clk,
    input  logic             dst_rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

  logic [WIDTH-1:0] stage0, stage1;

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      stage0 <= '0;
      stage1 <= '0;
    end else begin
      stage0 <= d;
      stage1 <= stage0;
    end
  end

  assign q = stage1;

endmodule
