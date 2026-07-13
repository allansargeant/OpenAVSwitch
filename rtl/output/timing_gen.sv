// Minimal parametrized video timing generator: produces de, a linear pixel
// address for active video, and a frame_start pulse a few lines into
// vertical blanking (not at the very start of the next frame) so that
// downstream frame-boundary latches (output_crossbar) and registered
// memory reads (frame_buffer_channel) have several cycles of margin to
// settle before the next frame's first active pixel — see
// output_crossbar.sv's latency note.
//
// Standing in for a real 4K HDMI transmitter's timing later; H/V
// active+blank are parameters specifically so this can be swapped for real
// CEA-861 timings without touching the module.
module timing_gen #(
    parameter int H_ACTIVE = 64,
    parameter int H_BLANK  = 16,
    parameter int V_ACTIVE = 48,
    parameter int V_BLANK  = 8
) (
    input logic clk,
    input logic rst_n,

    output logic                                     de,
    output logic                                     frame_start,
    output logic [$clog2(H_ACTIVE * V_ACTIVE)-1:0]   addr
);

  localparam int HTotal = H_ACTIVE + H_BLANK;
  localparam int VTotal = V_ACTIVE + V_BLANK;

  logic [$clog2(HTotal)-1:0] hcount;
  logic [$clog2(VTotal)-1:0] vcount;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hcount <= '0;
      vcount <= '0;
    end else if (hcount == HTotal - 1) begin
      hcount <= '0;
      vcount <= (vcount == VTotal - 1) ? '0 : vcount + 1'b1;
    end else begin
      hcount <= hcount + 1'b1;
    end
  end

  assign de          = (hcount < H_ACTIVE) && (vcount < V_ACTIVE);
  assign frame_start  = (hcount == 0) && (vcount == V_ACTIVE);
  assign addr         = de ? (vcount * H_ACTIVE + hcount) : '0;

endmodule
