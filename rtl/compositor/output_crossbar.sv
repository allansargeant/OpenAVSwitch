// The actual "seamless switch": channel_select is treated as an
// asynchronous request (it can change at any time, from any source) but is
// only latched — along with a snapshot of which buffer is latest-complete
// for every channel — at the output's own frame boundary (frame_start).
// This is what docs/architecture.md means by "switching is a read-pointer
// change, not a re-sync of the video path": nothing about any channel's
// capture path is touched here, we just decide, once per output frame,
// which already-live channel/buffer pair to read from.
//
// Latency note: chan_rd_data[c] is registered inside frame_buffer_channel
// (1 cycle after the address/buf_sel that produced it). active_channel is
// therefore delayed by one matching cycle (active_channel_d) before being
// used to select among chan_rd_data, and de_in is delayed the same way, so
// out_de/out_data are a consistent, aligned pair. This assumes the output
// timing generator's blanking interval is more than a couple of cycles
// long, which is true of any realistic video timing — the frame-boundary
// latch and the 1-cycle read latency both settle well before the new
// frame's first active pixel.
module output_crossbar #(
    parameter int NUM_CHANNELS = 4,
    parameter int DATA_WIDTH   = 16
) (
    input logic clk,
    input logic rst_n,

    input logic                                  frame_start,  // pulse at the output's own frame boundary
    input logic                                  de_in,        // de for the pixel whose address was just issued
    input logic [$clog2(NUM_CHANNELS)-1:0]       channel_select,             // async request; takes effect at next frame_start
    input logic [        NUM_CHANNELS-1:0]       chan_latest_complete_sync,  // per channel, from frame_buffer_channel
    input logic [        DATA_WIDTH-1:0]         chan_rd_data              [NUM_CHANNELS],

    output logic [NUM_CHANNELS-1:0]         buf_sel_out,     // -> each frame_buffer_channel.rd_buf_sel
    output logic [$clog2(NUM_CHANNELS)-1:0] active_channel,  // on-air channel this output frame (debug/testbench)
    output logic [DATA_WIDTH-1:0]           out_data,
    output logic                            out_de
);

  logic [$clog2(NUM_CHANNELS)-1:0] active_channel_d;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active_channel <= '0;
      buf_sel_out    <= '0;
    end else if (frame_start) begin
      active_channel <= channel_select;
      buf_sel_out    <= chan_latest_complete_sync;
    end
  end

  always_ff @(posedge clk) begin
    active_channel_d <= active_channel;
    out_de           <= de_in;
  end

  assign out_data = chan_rd_data[active_channel_d];

endmodule
