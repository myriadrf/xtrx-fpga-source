//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module lms7_tx_frm_brst_ex(
   input             rst,

   // LMS7
   output reg [11:0] out_sdr_ai,
   output reg [11:0] out_sdr_aq,
   output reg [11:0] out_sdr_bi,
   output reg [11:0] out_sdr_bq,
   output reg        out_strobe,
   input             mclk,
   // FIFO (RAM)
   input [47:0]      fifo_tdata,
   input             fifo_tvalid,
   output            fifo_tready,

   // MODE
   input             single_ch_mode,
   input [2:0]       inter_rate
);

wire [11:0] in_sampe_bi = fifo_tdata[11:0];
wire [11:0] in_sampe_ai = fifo_tdata[23:12];
wire [11:0] in_sampe_bq = fifo_tdata[35:24];
wire [11:0] in_sampe_aq = fifo_tdata[47:36];

wire [5:0] inter_val =
    (inter_rate == 0) ? 0 :
    (inter_rate == 1) ? 1 :
    (inter_rate == 2) ? 3 :
    (inter_rate == 3) ? 7 :
    (inter_rate == 4) ? 15 :
    (inter_rate == 5) ? 31 : 63;

reg       mode_siso;
reg       siso_switch;
reg [5:0] iter;

wire      sample_release = (inter_val == iter);

always @(posedge mclk) begin
  if (rst) begin
    iter <= 0;
  end else begin
    if (sample_release) begin
      iter <= 0;
    end else begin
      iter <= iter + 1;
    end
  end
end

assign fifo_tready = siso_switch && sample_release;

always @(posedge mclk) begin
  if (rst) begin
    out_sdr_ai    <= 12'b0;
    out_sdr_aq    <= 12'b0;
    out_sdr_bi    <= 12'b0;
    out_sdr_bq    <= 12'b0;
    out_strobe    <= 1'b0;

    mode_siso   <= single_ch_mode;
    siso_switch <= ~single_ch_mode;

  end else begin
    if (mode_siso && sample_release) begin
      siso_switch   <= ~siso_switch;
    end

    if (fifo_tvalid && sample_release) begin
      if (mode_siso) begin
        out_sdr_ai    <= (~siso_switch) ? in_sampe_ai : in_sampe_aq;
        out_sdr_bi    <= (~siso_switch) ? in_sampe_ai : in_sampe_aq;
        out_sdr_aq    <= (~siso_switch) ? in_sampe_bi : in_sampe_bq;
        out_sdr_bq    <= (~siso_switch) ? in_sampe_bi : in_sampe_bq;
      end else begin
        out_sdr_ai    <= in_sampe_ai;
        out_sdr_aq    <= in_sampe_aq;
        out_sdr_bi    <= in_sampe_bi;
        out_sdr_bq    <= in_sampe_bq;
      end
    end else if (~fifo_tvalid && sample_release) begin
      out_sdr_ai    <= 12'b0;
      out_sdr_aq    <= 12'b0;
      out_sdr_bi    <= 12'b0;
      out_sdr_bq    <= 12'b0;
    end

    out_strobe      <= sample_release;
  end
end

endmodule
