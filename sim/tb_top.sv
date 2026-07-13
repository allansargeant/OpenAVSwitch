// Top-level testbench for the Phase 1 logic/simulation track (see
// docs/phase1-plan.md). Wires 4 asynchronous sim video sources through 4
// frame_buffer_channels into one output_crossbar + timing_gen, drives
// channel_select changes at arbitrary times (deliberately not aligned to
// any frame boundary), and self-checks that:
//   1. no output frame ever mixes pixel data from two different sources
//      (that would mean a mid-frame tear), and
//   2. the decoded source in the output always matches the crossbar's own
//      active_channel record, and
//   3. no X/undefined bits ever appear in active-video output data.
`timescale 1ns / 1ps

module tb_top;

  localparam int NUM_CHANNELS = 4;
  localparam int DATA_WIDTH = 16;
  localparam int CHAN_BITS = 4;
  localparam int H_ACTIVE = 16;
  localparam int H_BLANK = 8;
  localparam int V_ACTIVE = 8;
  localparam int V_BLANK = 4;
  localparam int SEL_WIDTH = (NUM_CHANNELS > 1) ? $clog2(NUM_CHANNELS) : 1;

  // Independent, asynchronous clocks -- deliberately unrelated periods, none
  // a multiple of another, and none related to core_clk.
  logic clk0 = 0, clk1 = 0, clk2 = 0, clk3 = 0, core_clk = 0;
  always #3.5 clk0 = ~clk0;  // 7ns period
  always #5.5 clk1 = ~clk1;  // 11ns period
  always #6.5 clk2 = ~clk2;  // 13ns period
  always #8.5 clk3 = ~clk3;  // 17ns period
  always #2.0 core_clk = ~core_clk;  // 4ns period

  logic rst_n = 0;
  initial begin
    #50 rst_n = 1;
  end

  // --- 4 asynchronous sim sources ---
  logic src_de0, src_de1, src_de2, src_de3;
  logic src_fs0, src_fs1, src_fs2, src_fs3;
  logic [DATA_WIDTH-1:0] src_data0, src_data1, src_data2, src_data3;

  video_source_sim #(
      .CHANNEL_ID(0), .H_ACTIVE(H_ACTIVE), .H_BLANK(H_BLANK),
      .V_ACTIVE(V_ACTIVE), .V_BLANK(V_BLANK), .DATA_WIDTH(DATA_WIDTH), .CHAN_BITS(CHAN_BITS)
  ) u_src0 (
      .clk(clk0), .rst_n(rst_n), .de(src_de0), .frame_start(src_fs0), .data(src_data0)
  );
  video_source_sim #(
      .CHANNEL_ID(1), .H_ACTIVE(H_ACTIVE), .H_BLANK(H_BLANK),
      .V_ACTIVE(V_ACTIVE), .V_BLANK(V_BLANK), .DATA_WIDTH(DATA_WIDTH), .CHAN_BITS(CHAN_BITS)
  ) u_src1 (
      .clk(clk1), .rst_n(rst_n), .de(src_de1), .frame_start(src_fs1), .data(src_data1)
  );
  video_source_sim #(
      .CHANNEL_ID(2), .H_ACTIVE(H_ACTIVE), .H_BLANK(H_BLANK),
      .V_ACTIVE(V_ACTIVE), .V_BLANK(V_BLANK), .DATA_WIDTH(DATA_WIDTH), .CHAN_BITS(CHAN_BITS)
  ) u_src2 (
      .clk(clk2), .rst_n(rst_n), .de(src_de2), .frame_start(src_fs2), .data(src_data2)
  );
  video_source_sim #(
      .CHANNEL_ID(3), .H_ACTIVE(H_ACTIVE), .H_BLANK(H_BLANK),
      .V_ACTIVE(V_ACTIVE), .V_BLANK(V_BLANK), .DATA_WIDTH(DATA_WIDTH), .CHAN_BITS(CHAN_BITS)
  ) u_src3 (
      .clk(clk3), .rst_n(rst_n), .de(src_de3), .frame_start(src_fs3), .data(src_data3)
  );

  // --- 4 continuous-capture frame buffers, one per source ---
  logic [NUM_CHANNELS-1:0] chan_latest_complete_sync;
  logic [DATA_WIDTH-1:0] chan_rd_data[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0] buf_sel_out;
  logic [$clog2(H_ACTIVE*V_ACTIVE)-1:0] out_addr;

  frame_buffer_channel #(
      .H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE), .DATA_WIDTH(DATA_WIDTH)
  ) u_fb0 (
      .src_clk(clk0), .src_rst_n(rst_n), .src_de(src_de0), .src_frame_start(src_fs0), .src_data(src_data0),
      .rd_clk(core_clk), .rd_rst_n(rst_n), .rd_buf_sel(buf_sel_out[0]), .rd_addr(out_addr),
      .rd_data(chan_rd_data[0]), .latest_complete_sync(chan_latest_complete_sync[0])
  );
  frame_buffer_channel #(
      .H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE), .DATA_WIDTH(DATA_WIDTH)
  ) u_fb1 (
      .src_clk(clk1), .src_rst_n(rst_n), .src_de(src_de1), .src_frame_start(src_fs1), .src_data(src_data1),
      .rd_clk(core_clk), .rd_rst_n(rst_n), .rd_buf_sel(buf_sel_out[1]), .rd_addr(out_addr),
      .rd_data(chan_rd_data[1]), .latest_complete_sync(chan_latest_complete_sync[1])
  );
  frame_buffer_channel #(
      .H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE), .DATA_WIDTH(DATA_WIDTH)
  ) u_fb2 (
      .src_clk(clk2), .src_rst_n(rst_n), .src_de(src_de2), .src_frame_start(src_fs2), .src_data(src_data2),
      .rd_clk(core_clk), .rd_rst_n(rst_n), .rd_buf_sel(buf_sel_out[2]), .rd_addr(out_addr),
      .rd_data(chan_rd_data[2]), .latest_complete_sync(chan_latest_complete_sync[2])
  );
  frame_buffer_channel #(
      .H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE), .DATA_WIDTH(DATA_WIDTH)
  ) u_fb3 (
      .src_clk(clk3), .src_rst_n(rst_n), .src_de(src_de3), .src_frame_start(src_fs3), .src_data(src_data3),
      .rd_clk(core_clk), .rd_rst_n(rst_n), .rd_buf_sel(buf_sel_out[3]), .rd_addr(out_addr),
      .rd_data(chan_rd_data[3]), .latest_complete_sync(chan_latest_complete_sync[3])
  );

  // --- output timing + the actual seamless switch ---
  logic out_de_raw, out_frame_start;
  timing_gen #(
      .H_ACTIVE(H_ACTIVE), .H_BLANK(H_BLANK), .V_ACTIVE(V_ACTIVE), .V_BLANK(V_BLANK)
  ) u_out_timing (
      .clk(core_clk), .rst_n(rst_n), .de(out_de_raw), .frame_start(out_frame_start), .addr(out_addr)
  );

  logic [SEL_WIDTH-1:0] channel_select;
  logic [SEL_WIDTH-1:0] active_channel;
  logic [DATA_WIDTH-1:0] out_data;
  logic out_de;

  output_crossbar #(
      .NUM_CHANNELS(NUM_CHANNELS), .DATA_WIDTH(DATA_WIDTH)
  ) u_crossbar (
      .clk(core_clk), .rst_n(rst_n),
      .frame_start(out_frame_start), .de_in(out_de_raw),
      .channel_select(channel_select),
      .chan_latest_complete_sync(chan_latest_complete_sync),
      .chan_rd_data(chan_rd_data),
      .buf_sel_out(buf_sel_out),
      .active_channel(active_channel),
      .out_data(out_data),
      .out_de(out_de)
  );

  // --- stimulus: request channel changes at arbitrary times, deliberately
  //     not aligned to any source or output frame boundary. Spread across
  //     (and past) the checking_enabled window below so the self-check
  //     actually observes the switches, not just whatever channel was last
  //     selected before checking turned on.
  initial begin
    channel_select = '0;
    wait (rst_n);
    #12000 channel_select = 2'd1;
    #1345 channel_select = 2'd2;
    #987 channel_select = 2'd3;
    #2201 channel_select = 2'd0;
    #1654 channel_select = 2'd2;
    #3009 channel_select = 2'd1;
    #1877 channel_select = 2'd3;
    #999 channel_select = 2'd0;
  end

  // --- self-check ---
  function automatic logic [CHAN_BITS-1:0] decode_chan(logic [DATA_WIDTH-1:0] d);
    decode_chan = d[DATA_WIDTH-1:DATA_WIDTH-CHAN_BITS];
  endfunction

  int error_count;
  int frame_count;
  logic [NUM_CHANNELS-1:0] channels_seen;
  logic checking_enabled;
  logic frame_chan_id_valid;
  logic [CHAN_BITS-1:0] frame_chan_id;
  logic [CHAN_BITS-1:0] this_chan;

  initial begin
    error_count = 0;
    frame_count = 0;
    channels_seen = '0;
    checking_enabled = 0;
    frame_chan_id_valid = 0;
  end

  // Let every channel's ping-pong buffers fill at least once before checking.
  // Slowest source (clk3, 17ns period) takes ~288 cycles * 17ns ~= 4900ns
  // for its first complete frame; give it a full extra frame of margin.
  initial begin
    #10000 checking_enabled = 1;
  end

  always @(posedge core_clk) begin
    if (rst_n && out_frame_start) begin
      frame_count <= frame_count + 1;
      frame_chan_id_valid <= 1'b0;
    end
    if (rst_n && checking_enabled && out_de) begin
      this_chan = decode_chan(out_data);
      channels_seen[active_channel] <= 1'b1;
      if (!frame_chan_id_valid) begin
        frame_chan_id <= this_chan;
        frame_chan_id_valid <= 1'b1;
      end else if (this_chan !== frame_chan_id) begin
        $display("[%0t] ERROR: source mixed within one output frame! saw chan %0d after chan %0d (active_channel=%0d)",
                  $time, this_chan, frame_chan_id, active_channel);
        error_count <= error_count + 1;
      end
      if (this_chan !== active_channel) begin
        $display("[%0t] ERROR: decoded data channel %0d != crossbar active_channel %0d", $time, this_chan, active_channel);
        error_count <= error_count + 1;
      end
      if (^out_data === 1'bx) begin
        $display("[%0t] ERROR: out_data has X bits: %b", $time, out_data);
        error_count <= error_count + 1;
      end
    end
  end

  initial begin
    #60000;
    if (error_count == 0 && frame_count > 10 && channels_seen == {NUM_CHANNELS{1'b1}}) begin
      $display("TEST PASSED: %0d output frames observed, 0 errors, channels_seen=%b (all %0d exercised)",
                frame_count, channels_seen, NUM_CHANNELS);
    end else begin
      $display("TEST FAILED: %0d errors, %0d frames observed, channels_seen=%b", error_count, frame_count, channels_seen);
    end
    $finish;
  end

endmodule
