//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Register format
// 0: [1:0] Stop/8bit/12bit/16bit
// 1: [3:0] TX frontend buffering (min)

module lms7_rx_frm_brst #(
    parameter MAX_BURST_BITS = 14,
    parameter TS_BITS = 30
)(
   input             fe_reset,

   // AXI
   output reg [7:0]            axis_tx_tkeep,
   output reg [63:0]           axis_tx_tdata,
   output reg                  axis_tx_tvalid,
   output reg                  axis_tx_tlast,

   // Current time in RXFE domain
   output     [TS_BITS-1:0]    ts_current,

   // LMS7
   input [11:0]                in_sdr_ai,
   input [11:0]                in_sdr_aq,
   input [11:0]                in_sdr_bi,
   input [11:0]                in_sdr_bq,
   input                       in_sdr_valid,
   input                       in_sdr_clk,

   // LEGACY CONFIGURATION
   input                       in_mode_siso,
   input [1:0]                 in_fmt,
   input [1:0]                 decim_rate,

   // Modern configuration port
   input [31:0]                fe_cmd_data,
   input                       fe_cmd_valid,
   output                      fe_cmd_ready,

   // Cross-clock counter output
   input                       cc_rst,
   input                       cc_clk,
   output [31:0]               cc_ts_current
);

assign fe_cmd_ready = 1'b1;
wire [3:0]  fe_cmd_route        = fe_cmd_data[31:28];
wire [27:0] fe_cmd_route_data   = fe_cmd_data[27:0];

localparam FE_CMD_ROUTE_BURSTER = 0;
localparam FE_CMD_ROUTE_DSP0    = 1;

reg [MAX_BURST_BITS-1:0]  burst_samples_sz;
reg                       burst_throttle;
reg [7:0]                 burst_num_send;
reg [7:0]                 burst_num_skip;

localparam FE_CMD_ROUTE_BURST_TYPE_OFF = 27;
localparam FE_CMD_ROUTE_BURST_SAMPLES  = 1'b0;
localparam FE_CMD_ROUTE_BURST_THROTTLE = 1'b1;

always @(posedge in_sdr_clk) begin
  if (fe_reset) begin
    burst_samples_sz <= 511;
    burst_throttle   <= 0;
  end else begin
    if (fe_cmd_valid && fe_cmd_ready && (fe_cmd_route == FE_CMD_ROUTE_BURSTER)) begin
      case (fe_cmd_route_data[FE_CMD_ROUTE_BURST_TYPE_OFF])
        FE_CMD_ROUTE_BURST_SAMPLES: begin
          burst_samples_sz <= fe_cmd_route_data[MAX_BURST_BITS-1:0];
        end

        FE_CMD_ROUTE_BURST_THROTTLE: begin
          burst_num_skip   <= fe_cmd_route_data[7:0];
          burst_num_send   <= fe_cmd_route_data[15:8];
          burst_throttle   <= fe_cmd_route_data[16];
        end
      endcase
    end
  end
end


reg [MAX_BURST_BITS-1:0]  fe_cur_sample;
reg [7:0]                 fe_cur_burst;
reg                       fe_cur_burst_state;

always @(posedge in_sdr_clk) begin
  if (fe_reset) begin
    fe_cur_sample      <= burst_samples_sz;
    fe_cur_burst       <= 0;
    fe_cur_burst_state <= 0;
  end else begin
    if (in_sdr_valid) begin
      fe_cur_sample <= fe_cur_sample - 1;
      if (fe_cur_sample == 0) begin
        fe_cur_sample <= burst_samples_sz;

        if (burst_throttle) begin
          fe_cur_burst <= fe_cur_burst - 1;

          if (fe_cur_burst == 0) begin
            fe_cur_burst_state <= ~fe_cur_burst_state;
            if (fe_cur_burst_state == 0) begin
              fe_cur_burst <= burst_num_skip;
            end else begin
              fe_cur_burst <= burst_num_send;
            end
          end
        end
      end
    end
  end
end

wire burster_valid = in_sdr_valid && (~burst_throttle || ~fe_cur_burst_state);
wire burster_last  = (fe_cur_sample == 0);

wire [15:0] acc_ai;
wire [15:0] acc_aq;
wire [15:0] acc_bi;
wire [15:0] acc_bq;
wire        out_valid;
wire        out_last;

`ifndef RXDSP_CORE
`define RXDSP_CORE rxdsp_none
`endif

`RXDSP_CORE rxdsp(
   .clk(in_sdr_clk),
   .reset(fe_reset),

   .dspcmd_valid(fe_cmd_valid && fe_cmd_ready && (fe_cmd_route == FE_CMD_ROUTE_DSP0)),
   .dspcmd_data(fe_cmd_route_data),

   .dspcmd_legacy(decim_rate),

   .in_ai(in_sdr_ai),
   .in_aq(in_sdr_aq),
   .in_bi(in_sdr_bi),
   .in_bq(in_sdr_bq),
   .in_valid(burster_valid),
   .in_last(burster_last),

   .out_ai(acc_ai),
   .out_aq(acc_aq),
   .out_bi(acc_bi),
   .out_bq(acc_bq),
   .out_valid(out_valid),
   .out_last(out_last)
);

//////////////////////////////
// Data wire packager
//
reg [31:0]  tmp;

cross_counter #(
  .WIDTH(TS_BITS),
  .GRAY_BITS(4),
  .OUT_WIDTH(32),
  .OUT_LOWER_SKIP(0)
) ts_rx (
  .inrst(fe_reset),
  .inclk(in_sdr_clk),
  .incmdvalid(out_valid),
  .incmdinc(1'b1),
  .incnt(ts_current),

  .outrst(cc_rst),
  .outclk(cc_clk),
  .outcnt(cc_ts_current)
);


reg        iq_mux_valid;
reg        iq_mux_last;
reg [15:0] iq_mux_d0_i;
reg [15:0] iq_mux_d0_q;
reg [15:0] iq_mux_d1_i;
reg [15:0] iq_mux_d1_q;
reg        nxt_pkt;
reg        siso_last;

always @(posedge in_sdr_clk) begin
  if (fe_reset) begin
    iq_mux_valid       <= 0;
    siso_last          <= 0;
    nxt_pkt            <= 1'b1;
  end else if (out_valid) begin
    if (out_last) begin
      siso_last <= 0;
      nxt_pkt   <= 1'b1;
    end else begin
      siso_last <= ~siso_last;
      nxt_pkt   <= 1'b0;
    end

    if (in_mode_siso) begin
      if (~siso_last) begin
        iq_mux_d0_i <= acc_ai;
        iq_mux_d1_i <= acc_aq;
      end else begin
        iq_mux_d0_q <= acc_ai;
        iq_mux_d1_q <= acc_aq;
      end
    end else begin
      iq_mux_d0_i <= acc_ai;
      iq_mux_d0_q <= acc_aq;
      iq_mux_d1_i <= acc_bi;
      iq_mux_d1_q <= acc_bq;
    end
  end

  iq_mux_last  <= out_last;
  iq_mux_valid <= out_valid && (~in_mode_siso || siso_last);
end

`include "xtrxll_regs.vh"

wire [15:0] acc_i_8  = { iq_mux_d1_i[11:4],    iq_mux_d0_i[11:4] };
wire [15:0] acc_q_8  = { iq_mux_d1_q[11:4],    iq_mux_d0_q[11:4] };

wire [23:0] acc_i_12 = { iq_mux_d1_i[11:0],    iq_mux_d0_i[11:0] };
wire [23:0] acc_q_12 = { iq_mux_d1_q[11:0],    iq_mux_d0_q[11:0] };

wire [31:0] acc_i_16 = { iq_mux_d1_i,          iq_mux_d0_i };
wire [31:0] acc_q_16 = { iq_mux_d1_q,          iq_mux_d0_q };

wire        last_in_burst =  iq_mux_last;

reg [1:0]  nxt_transmit_state;

always @(posedge in_sdr_clk) begin
  if (fe_reset) begin
    nxt_transmit_state <= 2'b0;
  end else begin
    if (iq_mux_valid) begin
      nxt_transmit_state <= nxt_transmit_state + 1'b1;
    end
  end
end

always @(posedge in_sdr_clk) begin
  if (in_fmt == FMT_STOP) begin
    axis_tx_tlast  <= 0;
  end else begin
    axis_tx_tlast  <= last_in_burst;
  end
end

always @(posedge in_sdr_clk) begin
  case (in_fmt)
    FMT_STOP : begin
      axis_tx_tvalid <= 0;
    end

    FMT_8BIT: begin
        axis_tx_tvalid <= (nxt_transmit_state[0] || last_in_burst) && iq_mux_valid;

        if (nxt_transmit_state[0] == 0) begin
          axis_tx_tkeep        <= 8'h0f;
          axis_tx_tdata[15:0]  <= acc_i_8;
          axis_tx_tdata[31:16] <= acc_q_8;
        end else begin
          axis_tx_tkeep        <= 8'hff;
          axis_tx_tdata[47:32] <= acc_i_8;
          axis_tx_tdata[63:48] <= acc_q_8;
        end
    end

    FMT_12BIT: begin
      axis_tx_tvalid <= (nxt_transmit_state != 0 || last_in_burst) && iq_mux_valid;

      case (nxt_transmit_state)
        0: begin
          axis_tx_tkeep          <= 8'h3f;
          axis_tx_tdata[23:0]    <= acc_i_12;
          axis_tx_tdata[47:24]   <= acc_q_12;
        end

        1: begin
          axis_tx_tkeep          <= 8'hff;
          axis_tx_tdata[63:48]   <= acc_i_12[15:0];
          tmp[31:0]              <= { acc_q_12, acc_i_12[23:16] };
        end

        2: begin
          axis_tx_tkeep          <= 8'hff;
          axis_tx_tdata[31:0]    <= tmp[31:0];
          axis_tx_tdata[55:32]   <= acc_i_12;
          axis_tx_tdata[63:56]   <= acc_q_12[7:0];
          if (iq_mux_valid)
            tmp[15:0]              <= acc_q_12[23:8];
        end

        3: begin
          axis_tx_tkeep          <= 8'hff;
          axis_tx_tdata[15:0]    <= tmp[15:0];
          axis_tx_tdata[39:16]   <= acc_i_12;
          axis_tx_tdata[63:40]   <= acc_q_12;
        end
      endcase
    end

    FMT_16BIT: begin
      axis_tx_tvalid       <= iq_mux_valid;
      axis_tx_tkeep        <= 8'hff;

      axis_tx_tdata[31:0]  <= acc_i_16;
      axis_tx_tdata[63:32] <= acc_q_16;
    end

 endcase
end


endmodule
