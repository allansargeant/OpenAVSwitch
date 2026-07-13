// Top-level testbench for the Phase 1 logic/simulation track (see
// docs/phase1-plan.md). Wires 4 asynchronous sim video sources, each at
// its OWN native resolution (one matches the output, one upscales, one
// downscales, one uses a non-integer ratio), through frame_buffer_channel
// -> nn_scaler -> output_crossbar -> timing_gen, drives channel_select
// changes at arbitrary times, and self-checks that:
//   1. no output frame ever mixes pixel data from two different sources
//      (a mid-frame tear),
//   2. the decoded source always matches the crossbar's own
//      active_channel,
//   3. no X/undefined bits ever appear in active-video output data,
//   4. all 4 channels get exercised at least once, and
//   5. the decoded source (x, y) at every output pixel matches an
//      independently-computed nearest-neighbor reference — i.e. the
//      scaler is actually sampling the geometrically correct pixel, not
//      just "some" pixel from the right channel.
`timescale 1ns / 1ps

module tb_top;

  localparam int NUM_CHANNELS = 4;
  localparam int DATA_WIDTH = 16;
  localparam int CHAN_BITS = 4;
  localparam int X_BITS = 6;
  localparam int Y_BITS = 6;

  // Output resolution (what the crossbar/timing_gen actually drives).
  localparam int OUT_H_ACTIVE = 16;
  localparam int OUT_H_BLANK = 8;
  localparam int OUT_V_ACTIVE = 8;
  localparam int OUT_V_BLANK = 4;
  localparam int SEL_WIDTH = (NUM_CHANNELS > 1) ? $clog2(NUM_CHANNELS) : 1;

  // Each channel's own native resolution -- deliberately mismatched vs the
  // output and vs each other, to actually exercise the scaler. (Icarus
  // doesn't support unpacked array parameters, so these are spelled out
  // per channel rather than indexed arrays.)
  //   ch0: 16x8  -- matches output exactly (no-scale regression case)
  //   ch1: 8x4   -- 2x upscale
  //   ch2: 32x16 -- 2x downscale
  //   ch3: 12x6  -- non-integer (4/3) upscale
  localparam int CH0_H_ACTIVE = 16, CH0_H_BLANK = 8, CH0_V_ACTIVE = 8, CH0_V_BLANK = 4;
  localparam int CH1_H_ACTIVE = 8, CH1_H_BLANK = 8, CH1_V_ACTIVE = 4, CH1_V_BLANK = 4;
  localparam int CH2_H_ACTIVE = 32, CH2_H_BLANK = 8, CH2_V_ACTIVE = 16, CH2_V_BLANK = 4;
  localparam int CH3_H_ACTIVE = 12, CH3_H_BLANK = 8, CH3_V_ACTIVE = 6, CH3_V_BLANK = 4;

  // Independent, asynchronous clocks -- deliberately unrelated periods,
  // none a multiple of another, and none related to core_clk.
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

  // --- 4 asynchronous sim sources, each at its own native resolution ---
  logic src_de0, src_de1, src_de2, src_de3;
  logic src_fs0, src_fs1, src_fs2, src_fs3;
  logic [DATA_WIDTH-1:0] src_data0, src_data1, src_data2, src_data3;

  video_source_sim #(
      .CHANNEL_ID(0), .H_ACTIVE(CH0_H_ACTIVE), .H_BLANK(CH0_H_BLANK),
      .V_ACTIVE(CH0_V_ACTIVE), .V_BLANK(CH0_V_BLANK), .DATA_WIDTH(DATA_WIDTH),
      .CHAN_BITS(CHAN_BITS), .X_BITS(X_BITS), .Y_BITS(Y_BITS)
  ) u_src0 (
      .clk(clk0), .rst_n(rst_n), .de(src_de0), .frame_start(src_fs0), .data(src_data0)
  );
  video_source_sim #(
      .CHANNEL_ID(1), .H_ACTIVE(CH1_H_ACTIVE), .H_BLANK(CH1_H_BLANK),
      .V_ACTIVE(CH1_V_ACTIVE), .V_BLANK(CH1_V_BLANK), .DATA_WIDTH(DATA_WIDTH),
      .CHAN_BITS(CHAN_BITS), .X_BITS(X_BITS), .Y_BITS(Y_BITS)
  ) u_src1 (
      .clk(clk1), .rst_n(rst_n), .de(src_de1), .frame_start(src_fs1), .data(src_data1)
  );
  video_source_sim #(
      .CHANNEL_ID(2), .H_ACTIVE(CH2_H_ACTIVE), .H_BLANK(CH2_H_BLANK),
      .V_ACTIVE(CH2_V_ACTIVE), .V_BLANK(CH2_V_BLANK), .DATA_WIDTH(DATA_WIDTH),
      .CHAN_BITS(CHAN_BITS), .X_BITS(X_BITS), .Y_BITS(Y_BITS)
  ) u_src2 (
      .clk(clk2), .rst_n(rst_n), .de(src_de2), .frame_start(src_fs2), .data(src_data2)
  );
  video_source_sim #(
      .CHANNEL_ID(3), .H_ACTIVE(CH3_H_ACTIVE), .H_BLANK(CH3_H_BLANK),
      .V_ACTIVE(CH3_V_ACTIVE), .V_BLANK(CH3_V_BLANK), .DATA_WIDTH(DATA_WIDTH),
      .CHAN_BITS(CHAN_BITS), .X_BITS(X_BITS), .Y_BITS(Y_BITS)
  ) u_src3 (
      .clk(clk3), .rst_n(rst_n), .de(src_de3), .frame_start(src_fs3), .data(src_data3)
  );

  // --- output timing (drives the crossbar and every channel's scaler) ---
  logic out_de_raw, out_frame_start;
  logic [$clog2(OUT_H_ACTIVE)-1:0] out_x;
  logic [$clog2(OUT_V_ACTIVE)-1:0] out_y;

  timing_gen #(
      .H_ACTIVE(OUT_H_ACTIVE), .H_BLANK(OUT_H_BLANK), .V_ACTIVE(OUT_V_ACTIVE), .V_BLANK(OUT_V_BLANK)
  ) u_out_timing (
      .clk(core_clk), .rst_n(rst_n), .de(out_de_raw), .frame_start(out_frame_start), .x(out_x), .y(out_y)
  );

  // --- 4 continuous-capture frame buffers, each fed through its own
  //     nearest-neighbor scaler mapping output (x,y) into that channel's
  //     own native resolution ---
  logic [NUM_CHANNELS-1:0] chan_latest_complete_sync;
  logic [DATA_WIDTH-1:0] chan_rd_data[NUM_CHANNELS];
  logic [NUM_CHANNELS-1:0] buf_sel_out;

  logic [$clog2(CH0_H_ACTIVE*CH0_V_ACTIVE)-1:0] scaled_addr0;
  logic [$clog2(CH1_H_ACTIVE*CH1_V_ACTIVE)-1:0] scaled_addr1;
  logic [$clog2(CH2_H_ACTIVE*CH2_V_ACTIVE)-1:0] scaled_addr2;
  logic [$clog2(CH3_H_ACTIVE*CH3_V_ACTIVE)-1:0] scaled_addr3;

  nn_scaler #(.SRC_W(CH0_H_ACTIVE), .SRC_H(CH0_V_ACTIVE), .DST_W(OUT_H_ACTIVE), .DST_H(OUT_V_ACTIVE))
      u_scale0 (.dst_x(out_x), .dst_y(out_y), .src_addr(scaled_addr0));
  nn_scaler #(.SRC_W(CH1_H_ACTIVE), .SRC_H(CH1_V_ACTIVE), .DST_W(OUT_H_ACTIVE), .DST_H(OUT_V_ACTIVE))
      u_scale1 (.dst_x(out_x), .dst_y(out_y), .src_addr(scaled_addr1));
  nn_scaler #(.SRC_W(CH2_H_ACTIVE), .SRC_H(CH2_V_ACTIVE), .DST_W(OUT_H_ACTIVE), .DST_H(OUT_V_ACTIVE))
      u_scale2 (.dst_x(out_x), .dst_y(out_y), .src_addr(scaled_addr2));
  nn_scaler #(.SRC_W(CH3_H_ACTIVE), .SRC_H(CH3_V_ACTIVE), .DST_W(OUT_H_ACTIVE), .DST_H(OUT_V_ACTIVE))
      u_scale3 (.dst_x(out_x), .dst_y(out_y), .src_addr(scaled_addr3));

  frame_buffer_channel #(.H_ACTIVE(CH0_H_ACTIVE), .V_ACTIVE(CH0_V_ACTIVE), .DATA_WIDTH(DATA_WIDTH)) u_fb0 (
      .src_clk(clk0), .src_rst_n(rst_n), .src_de(src_de0), .src_frame_start(src_fs0), .src_data(src_data0),
      .rd_clk(core_clk), .rd_rst_n(rst_n), .rd_buf_sel(buf_sel_out[0]), .rd_addr(scaled_addr0),
      .rd_data(chan_rd_data[0]), .latest_complete_sync(chan_latest_complete_sync[0])
  );
  frame_buffer_channel #(.H_ACTIVE(CH1_H_ACTIVE), .V_ACTIVE(CH1_V_ACTIVE), .DATA_WIDTH(DATA_WIDTH)) u_fb1 (
      .src_clk(clk1), .src_rst_n(rst_n), .src_de(src_de1), .src_frame_start(src_fs1), .src_data(src_data1),
      .rd_clk(core_clk), .rd_rst_n(rst_n), .rd_buf_sel(buf_sel_out[1]), .rd_addr(scaled_addr1),
      .rd_data(chan_rd_data[1]), .latest_complete_sync(chan_latest_complete_sync[1])
  );
  frame_buffer_channel #(.H_ACTIVE(CH2_H_ACTIVE), .V_ACTIVE(CH2_V_ACTIVE), .DATA_WIDTH(DATA_WIDTH)) u_fb2 (
      .src_clk(clk2), .src_rst_n(rst_n), .src_de(src_de2), .src_frame_start(src_fs2), .src_data(src_data2),
      .rd_clk(core_clk), .rd_rst_n(rst_n), .rd_buf_sel(buf_sel_out[2]), .rd_addr(scaled_addr2),
      .rd_data(chan_rd_data[2]), .latest_complete_sync(chan_latest_complete_sync[2])
  );
  frame_buffer_channel #(.H_ACTIVE(CH3_H_ACTIVE), .V_ACTIVE(CH3_V_ACTIVE), .DATA_WIDTH(DATA_WIDTH)) u_fb3 (
      .src_clk(clk3), .src_rst_n(rst_n), .src_de(src_de3), .src_frame_start(src_fs3), .src_data(src_data3),
      .rd_clk(core_clk), .rd_rst_n(rst_n), .rd_buf_sel(buf_sel_out[3]), .rd_addr(scaled_addr3),
      .rd_data(chan_rd_data[3]), .latest_complete_sync(chan_latest_complete_sync[3])
  );

  // --- the actual seamless switch ---
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
  //     actually observes the switches. Channel 2 (32x16, the slowest to
  //     fill its buffer) gets a long dwell to make sure it's actually
  //     exercised, not just skipped past.
  initial begin
    channel_select = '0;
    wait (rst_n);
    #21000 channel_select = 2'd1;
    #8000 channel_select = 2'd2;
    #15000 channel_select = 2'd3;
    #9000 channel_select = 2'd0;
    #12000 channel_select = 2'd2;
    #10000 channel_select = 2'd1;
    #9000 channel_select = 2'd3;
    #8000 channel_select = 2'd0;
  end

  // --- self-check ---
  function automatic logic [CHAN_BITS-1:0] decode_chan(logic [DATA_WIDTH-1:0] d);
    decode_chan = d[DATA_WIDTH-1:DATA_WIDTH-CHAN_BITS];
  endfunction
  function automatic logic [Y_BITS-1:0] decode_y(logic [DATA_WIDTH-1:0] d);
    decode_y = d[DATA_WIDTH-CHAN_BITS-1:X_BITS];
  endfunction
  function automatic logic [X_BITS-1:0] decode_x(logic [DATA_WIDTH-1:0] d);
    decode_x = d[X_BITS-1:0];
  endfunction

  // Independent reference model for nearest-neighbor mapping, mirroring
  // nn_scaler.sv's formula but written separately so this check can catch
  // real RTL/wiring bugs rather than just agreeing with itself.
  localparam int FRAC_BITS = 16;
  function automatic int golden_nn(int dst_coord, int src_dim, int dst_dim);
    int step;
    int raw;
    step = (src_dim << FRAC_BITS) / dst_dim;
    raw = (dst_coord * step) >> FRAC_BITS;
    golden_nn = (raw >= src_dim) ? (src_dim - 1) : raw;
  endfunction

  // Icarus doesn't support unpacked array parameters, so channel dimension
  // lookup for the golden model is a case statement instead of indexing.
  function automatic int golden_nn_x(int dst_x_in, logic [SEL_WIDTH-1:0] chan);
    case (chan)
      0: golden_nn_x = golden_nn(dst_x_in, CH0_H_ACTIVE, OUT_H_ACTIVE);
      1: golden_nn_x = golden_nn(dst_x_in, CH1_H_ACTIVE, OUT_H_ACTIVE);
      2: golden_nn_x = golden_nn(dst_x_in, CH2_H_ACTIVE, OUT_H_ACTIVE);
      default: golden_nn_x = golden_nn(dst_x_in, CH3_H_ACTIVE, OUT_H_ACTIVE);
    endcase
  endfunction
  function automatic int golden_nn_y(int dst_y_in, logic [SEL_WIDTH-1:0] chan);
    case (chan)
      0: golden_nn_y = golden_nn(dst_y_in, CH0_V_ACTIVE, OUT_V_ACTIVE);
      1: golden_nn_y = golden_nn(dst_y_in, CH1_V_ACTIVE, OUT_V_ACTIVE);
      2: golden_nn_y = golden_nn(dst_y_in, CH2_V_ACTIVE, OUT_V_ACTIVE);
      default: golden_nn_y = golden_nn(dst_y_in, CH3_V_ACTIVE, OUT_V_ACTIVE);
    endcase
  endfunction

  int error_count;
  int frame_count;
  logic [NUM_CHANNELS-1:0] channels_seen;
  logic checking_enabled;
  logic frame_chan_id_valid;
  logic [CHAN_BITS-1:0] frame_chan_id;
  logic [CHAN_BITS-1:0] this_chan;
  logic [$clog2(OUT_H_ACTIVE)-1:0] out_x_d1;
  logic [$clog2(OUT_V_ACTIVE)-1:0] out_y_d1;
  int exp_x, exp_y;
  int act_x, act_y;

  initial begin
    error_count = 0;
    frame_count = 0;
    channels_seen = '0;
    checking_enabled = 0;
    frame_chan_id_valid = 0;
  end

  // Slowest channel (ch2: 32x16, HTotal=40, VTotal=20 -> 800 cycles, on a
  // 13ns clock) takes ~10.4us for its first complete frame. Give it a
  // full extra frame of margin before trusting any buffer's contents.
  initial begin
    #21000 checking_enabled = 1;
  end

  // out_data/out_de lag the (out_x, out_y) that produced them by exactly
  // one core_clk cycle (frame_buffer_channel's registered read) -- keep a
  // matching 1-cycle-delayed copy of the coordinates to compare against.
  always_ff @(posedge core_clk) begin
    out_x_d1 <= out_x;
    out_y_d1 <= out_y;
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

      // Scaler spatial-correctness check against the independent golden model.
      act_x = int'(decode_x(out_data));
      act_y = int'(decode_y(out_data));
      exp_x = golden_nn_x(int'(out_x_d1), active_channel);
      exp_y = golden_nn_y(int'(out_y_d1), active_channel);
      if (act_x !== exp_x || act_y !== exp_y) begin
        $display("[%0t] ERROR: scaler mismatch on chan %0d: out(x=%0d,y=%0d) -> got src(x=%0d,y=%0d), expected src(x=%0d,y=%0d)",
                  $time, active_channel, out_x_d1, out_y_d1, act_x, act_y, exp_x, exp_y);
        error_count <= error_count + 1;
      end
    end
  end

  initial begin
    #130000;
    if (error_count == 0 && frame_count > 10 && channels_seen == {NUM_CHANNELS{1'b1}}) begin
      $display("TEST PASSED: %0d output frames observed, 0 errors, channels_seen=%b (all %0d exercised)",
                frame_count, channels_seen, NUM_CHANNELS);
    end else begin
      $display("TEST FAILED: %0d errors, %0d frames observed, channels_seen=%b", error_count, frame_count, channels_seen);
    end
    $finish;
  end

endmodule
