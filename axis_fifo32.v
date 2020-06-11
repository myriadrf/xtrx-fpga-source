//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module axis_fifo32 #(
  parameter WIDTH = 32,
  parameter DEEP_BITS = 5
) (
  input clk,
  input axisrst,

  input [WIDTH-1:0]  axis_rx_tdata,
  input              axis_rx_tvalid,
  output             axis_rx_tready,

  output [WIDTH-1:0] axis_tx_tdata,
  output             axis_tx_tvalid,
  input              axis_tx_tready,

  output [DEEP_BITS-1:0] fifo_used,

  output reg             fifo_empty
);

reg [DEEP_BITS-1:0] rpos;

assign fifo_used = rpos;

localparam FIFO_FULL = ((1 << DEEP_BITS) - 1);

assign axis_tx_tvalid = (~fifo_empty);
assign axis_rx_tready = (rpos != FIFO_FULL);

wire fifo_wr_strobe = axis_rx_tvalid && axis_rx_tready;
wire fifo_rd_strobe = axis_tx_tvalid && axis_tx_tready;

`ifdef SYM
localparam MAX_DEEP = 1 << DEEP_BITS;

reg [WIDTH-1:0] fifo[MAX_DEEP - 1:0];
always @(posedge clk) begin
  if (fifo_wr_strobe) begin
    fifo[0] <= axis_rx_tdata;
  end
end

generate
genvar i;
for (i = 1; i < MAX_DEEP; i=i+1) begin : srl
  always @(posedge clk) begin
    if (fifo_wr_strobe)
      fifo[i] <= fifo[i - 1];
  end
end
endgenerate

assign axis_tx_tdata = fifo[rpos];

`else
genvar i;
generate
if (DEEP_BITS == 5) begin
  for (i = 0; i < WIDTH; i=i+1) begin : srl32
   SRLC32E #(
     .INIT(32'h00000000)
   ) fifo32(
        .CLK(clk),
        .CE(fifo_wr_strobe),
        .D(axis_rx_tdata[i]),
        .A(rpos),
        .Q(axis_tx_tdata[i]),
        .Q31()
   );
  end
end else if (DEEP_BITS == 4) begin
  for (i = 0; i < WIDTH; i=i+1) begin : srl16
   SRL16E #(
     .INIT(16'h0000)
   ) fifo16 (
        .CLK(clk),
        .CE(fifo_wr_strobe),
        .D(axis_rx_tdata[i]),
        .A0(rpos[0]),
        .A1(rpos[1]),
        .A2(rpos[2]),
        .A3(rpos[3]),
        .Q(axis_tx_tdata[i])
   );
  end
end
endgenerate
`endif

always @(posedge clk) begin
  if (axisrst) begin
    fifo_empty <= 1;
    rpos       <= 0;
  end else begin
    if (fifo_wr_strobe && fifo_rd_strobe) begin
    end else if (fifo_wr_strobe) begin
      if (fifo_empty)
        fifo_empty <= 1'b0;
      else
        rpos <= rpos + 1;

    end else if (fifo_rd_strobe) begin
      if (rpos == 0)
        fifo_empty <= 1'b1;
      else
        rpos <= rpos - 1;

    end
  end
end


endmodule
