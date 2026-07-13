SRC := \
	../rtl/common/sync_2ff.sv \
	../rtl/capture/frame_buffer_channel.sv \
	../rtl/scaler/nn_scaler.sv \
	../rtl/compositor/output_crossbar.sv \
	../rtl/output/timing_gen.sv \
	models/video_source_sim.sv \
	tb_top.sv

.PHONY: sim clean

sim: tb_top.vvp
	vvp tb_top.vvp

tb_top.vvp: $(SRC)
	iverilog -g2012 -o tb_top.vvp $(SRC)

clean:
	rm -f tb_top.vvp
