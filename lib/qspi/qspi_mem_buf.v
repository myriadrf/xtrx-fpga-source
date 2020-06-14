//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module qspi_mem_buf #(
  parameter MEM_ADDRBITS = 6
)(
  input clk,
  input rst,

  // UL Write
  input [MEM_ADDRBITS-1:0]  mem_ul_waddr,
  input [31:0]              mem_ul_wdata,
  input                     mem_ul_wvalid,
  output                    mem_ul_wready,

  // UL Read address channel
  input [MEM_ADDRBITS-1:0]  mem_ul_araddr,
  input                     mem_ul_arvalid,
  output                    mem_ul_arready,

  // UL Read data channel signals
  output [31:0]             mem_ul_rdata,
  output                    mem_ul_rvalid,
  input                     mem_ul_rready,

  // QSPI PORT
  input [MEM_ADDRBITS-1:0]  qspimem_addr,
  input                     qspimem_valid,
  input                     qspimem_wr,
  input [31:0]              qspimem_out_data,
  output                    qspimem_ready,

  output [31:0]             qspimem_in_data,
  output                    qspimem_in_valid
);

wire        mem_qspi_rd = qspimem_valid && ~qspimem_wr;
wire        mem_qspi_wr = qspimem_valid && qspimem_wr;


wire [MEM_ADDRBITS-1:0] mem_addr_rd = (mem_qspi_rd) ? qspimem_addr : mem_ul_araddr;
wire [31:0]             mem_data_rd;
assign qspimem_in_data  = mem_data_rd;
assign mem_ul_rdata     = mem_data_rd;

assign qspimem_ready    = 1'b1;
assign qspimem_in_valid = mem_qspi_rd;

assign mem_ul_arready   = ~mem_qspi_rd && mem_ul_rready;
assign mem_ul_rvalid    = ~mem_qspi_rd && mem_ul_arvalid;

assign mem_ul_wready    = ~(mem_qspi_wr);


wire [MEM_ADDRBITS-1:0] mem_addr_wr = (mem_qspi_wr) ? qspimem_addr : mem_ul_waddr;
wire [31:0]             mem_data_wr = (mem_qspi_wr) ? qspimem_out_data : mem_ul_wdata;

ram64xsdp #(
  .WIDTH(32)
) ram (
 .wclk(clk),
 .we(mem_qspi_wr || mem_ul_wvalid),
 .waddr(mem_addr_wr),
 .datai(mem_data_wr),

 .raddr(mem_addr_rd),
 .datao(mem_data_rd)
);



endmodule
