//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module cmd_queue #(
   parameter TS_BITS         = 30,
   parameter CMD_QUEUE_BITS  = 5
)(
    // CMD clock
    input                                           newcmd_clk,
    input                                           newcmd_reset,

    // CMD control
    output                                          newcmd_ready,
    input                                           newcmd_valid,
    input  [TS_BITS - 1:0]                          newcmd_data,

    // CMD statistics
    input                                           newcmd_stat_ready,
    output                                          newcmd_stat_valid,
    output [31:0]                                   newcmd_stat_data,

    // Interrupt logic
    input                                           newcmd_int_ready,
    output reg                                      newcmd_int_valid,

    // TS clock
    input                                           ts_clk,
    input [TS_BITS - 1:0]                           ts_current,

    input                                           cmd_ready,
    output reg                                      cmd_valid
);

wire [TS_BITS-1:0]     readcmd_ts;
wire                   readcmd_queue_nonempty;
wire                   newcmd_sp_ready;

assign newcmd_ready = 1'b1;

axis_async_fifo32 #(
  .WIDTH(TS_BITS),
  .DEEP_BITS(CMD_QUEUE_BITS)
) cmdfifo (
  .clkrx(newcmd_clk),
  .rstrx(newcmd_reset),

  .axis_rx_tdata(newcmd_data),
  .axis_rx_tvalid(newcmd_valid),
  .axis_rx_tready(newcmd_sp_ready),

  .clktx(ts_clk),
  .rsttx(newcmd_reset),

  .axis_tx_tdata(readcmd_ts),
  .axis_tx_tvalid(readcmd_queue_nonempty),
  .axis_tx_tready(cmd_valid & cmd_ready)
);

assign newcmd_stat_valid                    = 1'b1;
assign newcmd_stat_data[31:CMD_QUEUE_BITS+1]= 0;
assign newcmd_stat_data[CMD_QUEUE_BITS]     = newcmd_sp_ready;
assign newcmd_stat_data[CMD_QUEUE_BITS-1:0] = 0;


reg newcmd_ready_prev;
always @(posedge newcmd_clk) begin
  if (newcmd_reset) begin
    newcmd_ready_prev  <= 1'b1;
  end else begin
    newcmd_ready_prev  <= newcmd_sp_ready;

    if (newcmd_sp_ready && ~newcmd_ready_prev) begin
      newcmd_int_valid <= 1'b1;
    end else if (newcmd_int_valid && newcmd_int_ready) begin
      newcmd_int_valid <= 1'b0;
    end
  end
end

reg                cmd_avaliable;
reg                ts_went_off_reg;
wire [TS_BITS-1:0] ts_diff     = readcmd_ts - ts_current - 1'b1;
wire               ts_went_off = ts_diff[TS_BITS-1];

always @(posedge ts_clk) begin
  if (newcmd_reset) begin
    cmd_avaliable   <= 0;
    cmd_valid       <= 0;
    ts_went_off_reg <= 0;
  end else begin
    if (cmd_valid == 0) begin
      cmd_avaliable   <= readcmd_queue_nonempty;
      ts_went_off_reg <= ts_went_off;
      cmd_valid       <= cmd_avaliable && ts_went_off_reg;
    end else if (cmd_valid & cmd_ready) begin
      cmd_avaliable   <= 0;
      ts_went_off_reg <= 0;
      cmd_valid       <= 0;
    end

  end
end


endmodule

