// Per-channel continuous-capture frame store.
//
// Implements the "continuous capture" principle from docs/architecture.md:
// the source side writes every incoming frame into a ping-pong pair of
// buffers, in the source's own (unsynchronized) clock domain, regardless of
// whether anything downstream is currently reading it. The read side lives
// in a different, unrelated clock domain (the shared/output domain) and can
// read a fully-formed frame out of either buffer at its own pace.
//
// CDC strategy: the *only* thing crossing clock domains is which buffer
// index is "latest complete" (latest_complete_sync, 1 bit for double
// buffering). It changes at most once per source frame and is held stable
// for a full frame time before it can change again, which is exactly the
// condition sync_2ff requires to be safe. Which buffer the read side
// actually reads from (rd_buf_sel) is supplied by the caller (see
// output_crossbar.sv) — this module deliberately does not decide that
// itself, because "don't change mid output-frame" is a decision that
// belongs to whoever owns the output frame boundary, not to storage.
//
// Storage note: `mem` below is a behavioral 2-buffer array, adequate for
// proving the CDC/switching logic in simulation. Real hardware will not
// synthesize this as-is — it maps to two dual-port BRAM/URAM instances (or
// a DDR4-backed frame buffer via the memory controller, per
// docs/architecture.md) and that mapping is deferred to the hardware
// bring-up track, not part of Phase 1's logic/simulation track.
module frame_buffer_channel #(
    parameter int H_ACTIVE   = 64,
    parameter int V_ACTIVE   = 48,
    parameter int DATA_WIDTH = 16
) (
    // source (capture) side — free-running, own clock domain
    input logic                  src_clk,
    input logic                  src_rst_n,
    input logic                  src_de,           // asserted while src_data is valid active-video pixel data
    input logic                  src_frame_start,  // one src_clk-cycle pulse, once per frame, during blanking (never concurrent with src_de)
    input logic [DATA_WIDTH-1:0] src_data,

    // shared/read side — different, unrelated clock domain
    input  logic                                       rd_clk,
    input  logic                                        rd_rst_n,
    input  logic                                        rd_buf_sel,  // which buffer to read; caller's responsibility to hold stable across its own frame
    input  logic [$clog2(H_ACTIVE * V_ACTIVE)-1:0]       rd_addr,
    output logic [                     DATA_WIDTH-1:0]  rd_data,     // valid the cycle after rd_addr/rd_buf_sel (registered read)
    output logic                                         latest_complete_sync
);

  localparam int Pixels    = H_ACTIVE * V_ACTIVE;
  localparam int AddrWidth = $clog2(Pixels);

  logic [DATA_WIDTH-1:0] mem[2][Pixels];

  // --- write side (src_clk domain) ---
  logic                 wr_buf_sel;
  logic [AddrWidth-1:0] wr_addr;
  logic                 latest_complete;

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
      wr_buf_sel      <= 1'b0;
      wr_addr         <= '0;
      latest_complete <= 1'b0;
    end else if (src_frame_start) begin
      // The buffer we were just writing is now a fully-complete frame.
      latest_complete <= wr_buf_sel;
      wr_buf_sel      <= ~wr_buf_sel;
      wr_addr         <= '0;
    end else if (src_de) begin
      wr_addr <= wr_addr + 1'b1;
    end
  end

  always_ff @(posedge src_clk) begin
    if (src_de) begin
      mem[wr_buf_sel][wr_addr] <= src_data;
    end
  end

  // --- CDC: only this single bit crosses domains ---
  sync_2ff #(
      .WIDTH(1)
  ) sync_latest_complete (
      .dst_clk  (rd_clk),
      .dst_rst_n(rd_rst_n),
      .d        (latest_complete),
      .q        (latest_complete_sync)
  );

  // --- read side (rd_clk domain) ---
  always_ff @(posedge rd_clk) begin
    rd_data <= mem[rd_buf_sel][rd_addr];
  end

endmodule
