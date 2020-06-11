//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module fe_rx_chain_brst #(
   parameter BUFFER_SIZE_BITS = 13,
   parameter TS_BITS = 30,
   parameter DIAG_BITS = 20
)(
  // LMS7
  input                 rx_clk,
  input [11:0]          sdr_ai,
  input [11:0]          sdr_aq,
  input [11:0]          sdr_bi,
  input [11:0]          sdr_bq,
  input                 sdr_valid,
  output                o_sdr_enable,

  // TS for timed commands
  output [TS_BITS-1:0]  ts_current,

  // TS
  input                 ts_command_valid,
  output                ts_command_ready,

  output                rx_running,

  // FE CTRL
  input                          rxfe_ctrl_clk,

  output [2:0]                   rxfe_bufpos,
  output                         rxfe_resume,
  input [7:0]                    rxfe_ctrl,

  // RAM FIFO Interface
  output                         rxfe_rxdma_ten,
  output [BUFFER_SIZE_BITS-1:0]  rxfe_rxdma_taddr,
  output [63:0]                  rxfe_rxdma_tdata_wr,

  input [31:0]                   rxfe_cmd_data,
  input                          rxfe_cmd_valid,
  output                         rxfe_cmd_ready,

  // Timestamp report in another clock domain
  output [31:0]         cc_ts_current
);

wire        s_ul_clk       = rxfe_ctrl_clk;

wire [1:0]  dma_decim_rate = rxfe_ctrl[1:0];
wire [1:0]  dma_fmt        = rxfe_ctrl[3:2];
wire        dma_siso_mode  = rxfe_ctrl[4];
wire        dma_enable     = rxfe_ctrl[5];
wire        frm_rst        = rxfe_ctrl[6];
wire        dma_stall      = rxfe_ctrl[7];


wire [63:0] axis_lms7_buff_tdata;
wire        axis_lms7_buff_tvalid;
wire        axis_lms7_buff_tlast;


wire        frm_enable;
wire        frm_stall;


sync_reg #(.ASYNC_RESET(1)) sync_reg_en_to_frm (
    .clk(rx_clk),
    .rst(frm_rst),
    .in(dma_enable),
    .out(frm_enable)
);

sync_reg sync_reg_stall_to_frm (
    .clk(rx_clk),
    .rst(frm_rst),
    .in(dma_stall),
    .out(frm_stall)
);

assign rx_running = frm_enable;

reg frm_resume_cmd_triggered;

sync_reg sync_reg_to_ul (
    .clk(s_ul_clk),
    .rst(~dma_enable),

    .in(frm_resume_cmd_triggered),
    .out(rxfe_resume)
);

assign ts_command_ready = 1'b1;

always @(posedge rx_clk or posedge frm_rst) begin
  if (frm_rst) begin
    frm_resume_cmd_triggered <= 0;
  end else begin
    if (ts_command_valid && ts_command_ready) begin
       if (frm_stall) begin
         frm_resume_cmd_triggered <= 1'b1;
       end
    end else begin
      if (frm_resume_cmd_triggered && ~frm_stall) begin
         frm_resume_cmd_triggered <= 1'b0;
      end
    end
  end
end

assign o_sdr_enable = dma_enable; //fe_enable;

wire fe_cmd_valid_cc;
wire fe_cmd_ready_cc;

axis_cc_flow_ctrl axis_cc_flow_ctrl(
  .s_axis_clk(s_ul_clk),
  .s_aresetn(dma_enable),
  .s_axis_valid(rxfe_cmd_valid),
  .s_axis_ready(rxfe_cmd_ready),

  .m_axis_clk(rx_clk),
  .m_aresetn(frm_enable),
  .m_axis_valid(fe_cmd_valid_cc),
  .m_axis_ready(fe_cmd_ready_cc)
);

lms7_rx_frm_brst lms7_rx_frm_brst(
   .fe_reset(~frm_enable),

   // AXI
   .axis_tx_tdata(axis_lms7_buff_tdata),
   .axis_tx_tvalid(axis_lms7_buff_tvalid),
   .axis_tx_tlast(axis_lms7_buff_tlast),
   .axis_tx_tkeep(),

   .ts_current(ts_current),

   .in_sdr_ai(sdr_ai),
   .in_sdr_aq(sdr_aq),
   .in_sdr_bi(sdr_bi),
   .in_sdr_bq(sdr_bq),
   .in_sdr_valid(sdr_valid),
   .in_sdr_clk(rx_clk),

   .in_mode_siso(dma_siso_mode),
   .in_fmt(dma_fmt),
   .decim_rate(dma_decim_rate),

   .fe_cmd_data(rxfe_cmd_data),
   .fe_cmd_valid(fe_cmd_valid_cc),
   .fe_cmd_ready(fe_cmd_ready_cc),

   .cc_rst(~dma_enable),
   .cc_clk(s_ul_clk),
   .cc_ts_current(cc_ts_current)
);

localparam GRAY_BITS = 3;
wire [GRAY_BITS:1]             wr_addr_aclk;
wire [BUFFER_SIZE_BITS-1:0]    wr_addr_rxclk;
assign rxfe_bufpos = wr_addr_aclk[GRAY_BITS:1];

cross_counter #(
   .WIDTH( BUFFER_SIZE_BITS ),
   .GRAY_BITS(GRAY_BITS + 1),
   .OUT_WIDTH(GRAY_BITS + 1),
   .OUT_LOWER_SKIP(1)
) cntr (
   .inrst(~frm_enable),
   .inclk(rx_clk),
   .incmdvalid(axis_lms7_buff_tvalid),
   .incmdinc(1'b1),
   .incnt(wr_addr_rxclk),

   .outrst(~dma_enable),
   .outclk(s_ul_clk),
   .outcnt(wr_addr_aclk)
);

assign rxfe_rxdma_taddr    = wr_addr_rxclk;
assign rxfe_rxdma_tdata_wr = axis_lms7_buff_tdata;
assign rxfe_rxdma_ten      = axis_lms7_buff_tvalid;


endmodule

