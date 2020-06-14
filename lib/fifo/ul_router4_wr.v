//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module ul_router4_wr #(
  parameter ADDR_WIDTH = 10,
  parameter DATA_WIDTH = 32
) (
    // UL clocks
    input s_ul_clk,
    input s_ul_aresetn,

    // UL Write channel 0
    input [ADDR_WIDTH - 1:0]  s0_ul_waddr,
    input [DATA_WIDTH - 1:0]  s0_ul_wdata,
    input                     s0_ul_wvalid,
    output                    s0_ul_wready,

    // UL Write channel 1
    input [ADDR_WIDTH - 1:0]  s1_ul_waddr,
    input [DATA_WIDTH - 1:0]  s1_ul_wdata,
    input                     s1_ul_wvalid,
    output                    s1_ul_wready,

    // UL Write channel 1
    input [ADDR_WIDTH - 1:0]  s2_ul_waddr,
    input [DATA_WIDTH - 1:0]  s2_ul_wdata,
    input                     s2_ul_wvalid,
    output                    s2_ul_wready,

    // UL Write channel 1
    input [ADDR_WIDTH - 1:0]  s3_ul_waddr,
    input [DATA_WIDTH - 1:0]  s3_ul_wdata,
    input                     s3_ul_wvalid,
    output                    s3_ul_wready,

    ////////////////////////////////////////////
    //Mux0
    // UL Write channel
    output [ADDR_WIDTH - 3:0]  m0_ul_waddr,
    output [DATA_WIDTH - 1:0]  m0_ul_wdata,
    output                     m0_ul_wvalid,
    input                      m0_ul_wready,

    ////////////////////////////////////////////
    //Mux1
    // UL Write channel
    output [ADDR_WIDTH - 3:0]  m1_ul_waddr,
    output [DATA_WIDTH - 1:0]  m1_ul_wdata,
    output                     m1_ul_wvalid,
    input                      m1_ul_wready,

    ////////////////////////////////////////////
    //Mux2
    // UL Write channel
    output [ADDR_WIDTH - 3:0]  m2_ul_waddr,
    output [DATA_WIDTH - 1:0]  m2_ul_wdata,
    output                     m2_ul_wvalid,
    input                      m2_ul_wready,

    ////////////////////////////////////////////
    //Mux3
    // UL Write channel
    output [ADDR_WIDTH - 3:0]  m3_ul_waddr,
    output [DATA_WIDTH - 1:0]  m3_ul_wdata,
    output                     m3_ul_wvalid,
    input                      m3_ul_wready
);

reg [ADDR_WIDTH - 1:0]  s_ul_waddr;
reg [DATA_WIDTH - 1:0]  s_ul_wdata;
reg                     s_ul_wvalid;
wire                    s_ul_wready;

assign s0_ul_wready = (~s_ul_wvalid || s_ul_wready);
assign s1_ul_wready = (~s_ul_wvalid || s_ul_wready) && ~s0_ul_wvalid;
assign s2_ul_wready = (~s_ul_wvalid || s_ul_wready) && ~s0_ul_wvalid && ~s1_ul_wvalid;
assign s3_ul_wready = (~s_ul_wvalid || s_ul_wready) && ~s0_ul_wvalid && ~s1_ul_wvalid && ~s2_ul_wvalid;

always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    s_ul_wvalid <= 1'b0;
  end else begin
    if (s0_ul_wvalid && s0_ul_wready) begin
      s_ul_waddr <= s0_ul_waddr;
      s_ul_wdata <= s0_ul_wdata;
      s_ul_wvalid <= 1'b1;
    end else if (s1_ul_wvalid && s1_ul_wready) begin
      s_ul_waddr <= s1_ul_waddr;
      s_ul_wdata <= s1_ul_wdata;
      s_ul_wvalid <= 1'b1;
    end else if (s2_ul_wvalid && s2_ul_wready) begin
      s_ul_waddr <= s2_ul_waddr;
      s_ul_wdata <= s2_ul_wdata;
      s_ul_wvalid <= 1'b1;
    end else if (s3_ul_wvalid && s3_ul_wready) begin
      s_ul_waddr <= s3_ul_waddr;
      s_ul_wdata <= s3_ul_wdata;
      s_ul_wvalid <= 1'b1;
    end else if (s_ul_wvalid && s_ul_wready) begin
      s_ul_wvalid <= 1'b0;
    end
  end
end


wire [1:0] wselector = s_ul_waddr[ADDR_WIDTH - 1:ADDR_WIDTH - 2];

assign m0_ul_waddr = s_ul_waddr[ADDR_WIDTH - 3:0];
assign m1_ul_waddr = s_ul_waddr[ADDR_WIDTH - 3:0];
assign m2_ul_waddr = s_ul_waddr[ADDR_WIDTH - 3:0];
assign m3_ul_waddr = s_ul_waddr[ADDR_WIDTH - 3:0];

assign m0_ul_wdata = s_ul_wdata;
assign m1_ul_wdata = s_ul_wdata;
assign m2_ul_wdata = s_ul_wdata;
assign m3_ul_wdata = s_ul_wdata;

assign s_ul_wready = (wselector == 2'b00) ? m0_ul_wready :
                     (wselector == 2'b01) ? m1_ul_wready :
                     (wselector == 2'b10) ? m2_ul_wready :
                                            m3_ul_wready;

assign m0_ul_wvalid = s_ul_wvalid && (wselector == 2'b00);
assign m1_ul_wvalid = s_ul_wvalid && (wselector == 2'b01);
assign m2_ul_wvalid = s_ul_wvalid && (wselector == 2'b10);
assign m3_ul_wvalid = s_ul_wvalid && (wselector == 2'b11);


endmodule



