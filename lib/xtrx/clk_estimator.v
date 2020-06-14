//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module clk_estimator #(
    parameter EST_BITS = 20
)(
    input         rst,
    input         clk,

    input         meas_clk,

    input         cntr_ready,
    output        cntr_valid,
    output [31:0] cntr_data
);


reg [EST_BITS-1:0] div_clk;
always @(posedge clk) begin
  if (rst) begin
    div_clk <= 0;
  end else begin
    div_clk <= div_clk + 1'b1;
  end
end

wire out_dclk;
sync_reg  self_estim(
    .clk(meas_clk),
    .rst(rst),
    .in(div_clk[EST_BITS-1]),
    .out(out_dclk)
);

reg [EST_BITS-1:0] cntr_clk;
reg [EST_BITS-1:0] ref_cntr_data_r;
reg [3:0]  evnts;
reg prev_out_dclk;

always @(posedge meas_clk) begin
  if (rst) begin
    cntr_clk        <= 0;
    prev_out_dclk   <= 0;
    ref_cntr_data_r <= 0;
    evnts           <= 0;
  end else begin
    prev_out_dclk   <= out_dclk;

    if (prev_out_dclk == 0 && out_dclk == 1'b1) begin
      cntr_clk        <= 0;
      ref_cntr_data_r <= cntr_clk;
      evnts           <= evnts + 1'b1;
    end else begin
      cntr_clk        <= cntr_clk + 1'b1;
    end
  end
end

// Self clock estimation
assign cntr_valid = 1'b1;
assign cntr_data = { evnts, {(28 - EST_BITS){1'b0}}, ref_cntr_data_r };



endmodule
