//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module ul_qspi_mem_async #(
    parameter MEM_ADDR_BITS = 16,
    parameter ASYNC_CLOCKS = 1
)(
    input         clk,
    input         reset,

    ///////////////////////////////
    // UL
    //
    ///// qspi excmd
    input         qspi_excmd_valid,
    input  [31:0] qspi_excmd_data,
    output        qspi_excmd_ready,

    ///// qspi cmd
    input         qspi_cmd_valid,
    input  [31:0] qspi_cmd_data,
    output        qspi_cmd_ready,

    ///// qspi debug Rd
    output        qspi_rd_valid,
    output [31:0] qspi_rd_data,
    input         qspi_rd_ready,

    ///// qspi status
    output        qspi_stat_valid,
    output [31:0] qspi_stat_data,
    input         qspi_stat_ready,

    //////////////////////////////
    // Buffer memory interface
    //
    output [MEM_ADDR_BITS - 1:2] mem_addr,
    output                       mem_valid,
    output                       mem_wr,
    output [31:0]                mem_out_data,
    input                        mem_ready,

    input [31:0]                 mem_in_data,
    input                        mem_in_valid,

    //////////////////////////////
    input            qphy_clk,
    input            qphy_reset,

    input   [3:0]    qphy_di,
    output  [3:0]    qphy_do,
    output  [3:0]    qphy_dt,
    output           qphy_dncs // Crystal select
);


// QSPI if
wire  [7:0] flash_cmd_data;
wire        flash_cmd_valid;
wire        flash_cmd_ready;
wire        flash_cmd_tlast;

wire  [7:0] qphy_flash_cmd_data;
wire        qphy_flash_cmd_valid;
wire        qphy_flash_cmd_ready;
wire        qphy_flash_cmd_tlast;

wire  [7:0] flash_in_data;
wire        flash_in_valid;
wire        flash_in_ready;
wire        flash_in_tlast;

wire  [7:0] qphy_flash_out_data;
wire        qphy_flash_out_valid;
wire        qphy_flash_out_ready;
wire        qphy_flash_out_tlast;


ul_qspi_mem ul_qspi_mem(
    .clk(clk),
    .reset(reset),

    ///////////////////////////////
    // UL
    //
    ///// qspi excmd
    .qspi_excmd_valid(qspi_excmd_valid),
    .qspi_excmd_data(qspi_excmd_data),
    .qspi_excmd_ready(qspi_excmd_ready),

    ///// qspi cmd
    .qspi_cmd_valid(qspi_cmd_valid),
    .qspi_cmd_data(qspi_cmd_data),
    .qspi_cmd_ready(qspi_cmd_ready),

    ///// qspi debug Rd
    .qspi_rd_valid(qspi_rd_valid),
    .qspi_rd_data(qspi_rd_data),
    .qspi_rd_ready(qspi_rd_ready),

    ///// qspi status
    .qspi_stat_valid(qspi_stat_valid),
    .qspi_stat_data(qspi_stat_data),
    .qspi_stat_ready(qspi_stat_ready),

    //////////////////////////////
    // Buffer memory interface
    //
    .mem_addr(mem_addr),
    .mem_valid(mem_valid),
    .mem_wr(mem_wr),
    .mem_out_data(mem_out_data),
    .mem_ready(mem_ready),

    .mem_in_data(mem_in_data),
    .mem_in_valid(mem_in_valid),

    //////////////////////////////
    // QSPI if
    .flash_cmd_data(flash_cmd_data),
    .flash_cmd_valid(flash_cmd_valid),
    .flash_cmd_ready(flash_cmd_ready),
    .flash_cmd_tlast(flash_cmd_tlast),

    .flash_in_data(flash_in_data),
    .flash_in_valid(flash_in_valid),
    .flash_in_ready(flash_in_ready),
    .flash_in_tlast(flash_in_tlast)
);

generate
if (ASYNC_CLOCKS != 0) begin

axis_async_fifo32 #(.WIDTH(9)) async_cmd_q (
  .clkrx(clk),
  .rstrx(reset),

  .axis_rx_tdata({flash_cmd_data, flash_cmd_tlast}),
  .axis_rx_tvalid(flash_cmd_valid),
  .axis_rx_tready(flash_cmd_ready),

  .clktx(qphy_clk),
  .rsttx(qphy_reset),

  .axis_tx_tdata({qphy_flash_cmd_data, qphy_flash_cmd_tlast}),
  .axis_tx_tvalid(qphy_flash_cmd_valid),
  .axis_tx_tready(qphy_flash_cmd_ready)
);

axis_async_fifo32 #(.WIDTH(9)) async_rb_q (
  .clkrx(qphy_clk),
  .rstrx(qphy_reset),

  .axis_rx_tdata({qphy_flash_out_data, qphy_flash_out_tlast}),
  .axis_rx_tvalid(qphy_flash_out_valid),
  .axis_rx_tready(qphy_flash_out_ready),

  .clktx(clk),
  .rsttx(reset),

  .axis_tx_tdata({flash_in_data, flash_in_tlast}),
  .axis_tx_tvalid(flash_in_valid),
  .axis_tx_tready(flash_in_ready)
);

end else begin

axis_fifo32 #(.WIDTH(9)) sync_cmd_q (
  .clk(clk),
  .axisrst(reset),

  .axis_rx_tdata({flash_cmd_data, flash_cmd_tlast}),
  .axis_rx_tvalid(flash_cmd_valid),
  .axis_rx_tready(flash_cmd_ready),

  .axis_tx_tdata({qphy_flash_cmd_data, qphy_flash_cmd_tlast}),
  .axis_tx_tvalid(qphy_flash_cmd_valid),
  .axis_tx_tready(qphy_flash_cmd_ready)
);

axis_fifo32 #(.WIDTH(9)) sync_rb_q (
  .clk(qphy_clk),
  .axisrst(reset),

  .axis_rx_tdata({qphy_flash_out_data, qphy_flash_out_tlast}),
  .axis_rx_tvalid(qphy_flash_out_valid),
  .axis_rx_tready(qphy_flash_out_ready),

  .axis_tx_tdata({flash_in_data, flash_in_tlast}),
  .axis_tx_tvalid(flash_in_valid),
  .axis_tx_tready(flash_in_ready)
);

end
endgenerate


qspi_flash qspi_flash (
    .clk(qphy_clk),
    .reset(qphy_reset),

    // Flash interface
    .di(qphy_di),
    .do(qphy_do),
    .dt(qphy_dt),
    .dncs(qphy_dncs), // Crystal select

    // XIP enabled, can sendout ADDR + data
    .flash_xip_enabled(),

    // Logical interface
    .flash_cmd_data(qphy_flash_cmd_data),
    .flash_cmd_valid(qphy_flash_cmd_valid),
    .flash_cmd_ready(qphy_flash_cmd_ready),
    .flash_cmd_tlast(qphy_flash_cmd_tlast),

    .flash_out_data(qphy_flash_out_data),
    .flash_out_valid(qphy_flash_out_valid),
    .flash_out_ready(qphy_flash_out_ready),
    .flash_out_tlast(qphy_flash_out_tlast)
);

endmodule
